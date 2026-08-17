import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import '../models/album_item.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import 'hc_api_service.dart';
import 'storage_service.dart';

typedef DownloadLogCallback = void Function(String message, String level);
typedef TaskProgressCallback = void Function(AlbumDownloadTask task);

const String kAlbumMetadataFilename = '.hc_album.json';

class DownloadEngine {
  final AppConfig config;
  final DownloadLogCallback onLog;
  final TaskProgressCallback? onTaskProgress;

  bool _isCancelled = false;
  late final Dio _dio;

  DownloadEngine({
    required this.config,
    required this.onLog,
    this.onTaskProgress,
  }) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Referer': '${HCApiService.kBaseUrl}/',
          'Connection': 'keep-alive',
        },
      ),
    );

    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;

      if (config.customProxy.trim().isNotEmpty) {
        final clean = config.customProxy.trim().replaceAll('http://', '').replaceAll('https://', '');
        client.findProxy = (uri) => 'PROXY $clean; DIRECT';
      } else {
        client.findProxy = (uri) => 'DIRECT';
      }
      return client;
    };
    _dio.httpClientAdapter = adapter;
  }

  void cancel() {
    _isCancelled = true;
  }

  /// Check if an image file exists with any common image extension
  static Future<File?> findExistingImageFile(String folderPath, int index, String expectedExt) async {
    // 1. Check expected extension
    final direct = File(p.join(folderPath, '$index.$expectedExt'));
    if (await direct.exists() && await direct.length() > 0) return direct;

    // 2. Check alternative extensions
    const exts = ['jpg', 'jpeg', 'webp', 'png', 'gif', 'bmp'];
    for (final ext in exts) {
      if (ext == expectedExt) continue;
      final f = File(p.join(folderPath, '$index.$ext'));
      if (await f.exists() && await f.length() > 0) return f;
    }
    return null;
  }

  /// Check if all images exist in target folder
  Future<bool> _allImagesExist(String folderPath, List<String> urls) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return false;
    if (urls.isEmpty) return false;

    for (int i = 0; i < urls.length; i++) {
      final ext = AlbumItem.resolveExt(urls[i]);
      final existing = await findExistingImageFile(folderPath, i + 1, ext);
      if (existing == null) return false;
    }
    return true;
  }

  /// Check if folder contains any valid images
  Future<bool> _hasAnyImages(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return false;
    try {
      final list = await dir.list().toList();
      for (final e in list) {
        if (e is File) {
          final ext = p.extension(e.path).replaceAll('.', '').toLowerCase();
          const validExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
          if (validExts.contains(ext) && await e.length() > 0) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Find all potential directory locations for an album (root or `archive/<author>/<album>`)
  Future<List<String>> _findCandidateFolders(String baseDir, String folderName) async {
    final List<String> candidates = [p.join(baseDir, folderName)];
    final archiveDir = Directory(p.join(baseDir, 'archive'));
    if (await archiveDir.exists()) {
      try {
        final authorEntities = await archiveDir.list().toList();
        for (final authorEntity in authorEntities) {
          if (authorEntity is Directory) {
            final archivedPackPath = p.join(authorEntity.path, folderName);
            candidates.add(archivedPackPath);
          }
        }
      } catch (_) {}
    }
    return candidates;
  }

  /// Select the best folder (prioritizing completely downloaded archived or root folders)
  Future<MapEntry<String, bool>> _selectAlbumFolder(
    String baseDir,
    AlbumItem item,
  ) async {
    final folderName = AlbumItem.cleanFilename(item.title);

    if (config.autoArchive) {
      final authorName = AlbumItem.cleanArchiveSegment(item.author);
      final authorFolder = p.join(baseDir, 'archive', authorName, folderName);
      if (item.imageUrls.isNotEmpty && await _allImagesExist(authorFolder, item.imageUrls)) {
        return MapEntry(authorFolder, true);
      }
    }

    final candidates = await _findCandidateFolders(baseDir, folderName);
    // 1. Check complete
    for (final folder in candidates) {
      if (item.imageUrls.isNotEmpty && await _allImagesExist(folder, item.imageUrls)) {
        return MapEntry(folder, true);
      }
    }
    // 2. Check partial
    for (final folder in candidates) {
      if (await _hasAnyImages(folder)) {
        return MapEntry(folder, false);
      }
    }

    // Default target
    if (config.autoArchive) {
      final authorName = AlbumItem.cleanArchiveSegment(item.author);
      return MapEntry(p.join(baseDir, 'archive', authorName, folderName), false);
    } else {
      return MapEntry(p.join(baseDir, folderName), false);
    }
  }

  /// Write .hc_album.json metadata file
  Future<void> _writeAlbumMetadata(String folderPath, AlbumItem item) async {
    try {
      final file = File(p.join(folderPath, kAlbumMetadataFilename));
      final payload = {
        'saved_at': DateTime.now().toIso8601String(),
        'title': item.title,
        'slug': item.slug,
        'author': item.author,
        'date': item.date,
        'detailUrl': item.detailUrl,
        'coverUrl': item.coverUrl,
        'imageCount': item.imageUrls.length,
        'imageUrls': item.imageUrls,
        'tags': item.tags,
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (_) {}
  }

  /// Download a single image with retry, existence check, and atomic file write
  Future<ImageTaskStatus> downloadImage({
    required String originalUrl,
    required String savePath,
    required ImageDownloadTask imageTask,
    required void Function(int bytes) onBytesReceived,
  }) async {
    final folderPath = p.dirname(savePath);
    final ext = p.extension(savePath).replaceAll('.', '');

    // 1. Check if already exists (with any valid format)
    final existingFile = await findExistingImageFile(folderPath, imageTask.index, ext);
    if (existingFile != null) {
      final len = await existingFile.length();
      if (len > 0) {
        imageTask.status = ImageTaskStatus.skipped;
        imageTask.downloadedBytes = len;
        imageTask.totalBytes = len;
        return ImageTaskStatus.skipped;
      }
    }

    if (_isCancelled) {
      imageTask.status = ImageTaskStatus.failed;
      return ImageTaskStatus.failed;
    }

    final random = Random();

    for (int i = 0; i < config.retryCount; i++) {
      if (_isCancelled) break;

      try {
        final tempFile = File('$savePath.tmp_${DateTime.now().microsecondsSinceEpoch}');
        if (await tempFile.exists()) await tempFile.delete();

        imageTask.status = ImageTaskStatus.downloading;

        int lastBytes = 0;
        final response = await _dio.download(
          originalUrl,
          tempFile.path,
          onReceiveProgress: (received, total) {
            final delta = received - lastBytes;
            if (delta > 0) {
              lastBytes = received;
              onBytesReceived(delta);
            }
            imageTask.downloadedBytes = received;
            imageTask.totalBytes = total > 0 ? total : received;
          },
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 200) {
          if (await tempFile.exists() && await tempFile.length() > 0) {
            final targetFile = File(savePath);
            if (await targetFile.exists()) await targetFile.delete();
            await tempFile.rename(targetFile.path);
            imageTask.status = ImageTaskStatus.success;
            return ImageTaskStatus.success;
          }
        }

        if (await tempFile.exists()) await tempFile.delete();
      } catch (e) {
        if (i < config.retryCount - 1) {
          final delayMs = 600 + random.nextInt(1000);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    imageTask.status = ImageTaskStatus.failed;
    imageTask.error = '单图下载失败';
    onLog('单图下载失败: ${p.basename(savePath)}', 'warn');
    return ImageTaskStatus.failed;
  }

  /// Process an entire album task with image concurrency and smart skip detection
  Future<AlbumDownloadTask> processAlbum(
    AlbumDownloadTask task,
    String baseDir, {
    required void Function(int bytes) onBytesReceived,
  }) async {
    var item = task.albumItem;

    // 1. If detail is not loaded, fetch it now to get full imageUrls
    if (!item.isDetailLoaded || item.imageUrls.isEmpty) {
      onLog('正在解析图集详情: ${item.title}', 'info');
      final detailedItem = await HCApiService.fetchAlbumDetail(item);
      if (detailedItem != null && detailedItem.imageUrls.isNotEmpty) {
        item = detailedItem;
      } else {
        onLog('解析图集详情失败或相册为空: ${item.title}', 'error');
        task.status = TaskStatus.failed;
        onTaskProgress?.call(task);
        return task;
      }
    }

    // 2. Folder selection & complete check
    final selectedFolderResult = await _selectAlbumFolder(baseDir, item);
    final targetFolder = selectedFolderResult.key;
    final isComplete = selectedFolderResult.value;
    final dir = Directory(targetFolder);

    task.targetFolder = targetFolder;
    task.totalImages = item.imageUrls.length;
    task.status = TaskStatus.downloading;
    task.startTime ??= DateTime.now();

    // Rebuild image tasks
    task.imageTasks.clear();
    for (int i = 0; i < item.imageUrls.length; i++) {
      final ext = AlbumItem.resolveExt(item.imageUrls[i]);
      final savePath = p.join(targetFolder, '${i + 1}.$ext');
      task.imageTasks.add(
        ImageDownloadTask(
          index: i + 1,
          originalUrl: item.imageUrls[i],
          savePath: savePath,
        ),
      );
    }

    onTaskProgress?.call(task);

    // Skip if complete
    if (isComplete) {
      task.skippedImages = item.imageUrls.length;
      task.downloadedImages = 0;
      task.failedImages = 0;
      task.downloadedBytes = await StorageService.getFolderSize(targetFolder);
      task.status = TaskStatus.completed;
      task.finishTime = DateTime.now();
      for (final imgTask in task.imageTasks) {
        imgTask.status = ImageTaskStatus.skipped;
      }
      onLog('已下载完整图集，跳过: ${item.title} (${item.imageUrls.length}张)', 'info');
      onTaskProgress?.call(task);
      return task;
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 3. Multi-threaded image concurrency pool (using config.imgWorkers!)
    final imagePool = Pool(config.imgWorkers.clamp(1, 40));
    final List<Future<void>> futures = [];

    for (int i = 0; i < task.imageTasks.length; i++) {
      final imgTask = task.imageTasks[i];
      final future = imagePool.withResource(() async {
        if (_isCancelled) return;
        final res = await downloadImage(
          originalUrl: imgTask.originalUrl,
          savePath: imgTask.savePath,
          imageTask: imgTask,
          onBytesReceived: onBytesReceived,
        );

        if (res == ImageTaskStatus.success) {
          task.downloadedImages++;
        } else if (res == ImageTaskStatus.skipped) {
          task.skippedImages++;
        } else {
          task.failedImages++;
        }

        onTaskProgress?.call(task);
      });
      futures.add(future);
    }

    await Future.wait(futures);

    // Calculate total bytes
    int totalBytes = 0;
    for (final img in task.imageTasks) {
      totalBytes += img.downloadedBytes;
    }
    if (totalBytes == 0 && targetFolder.isNotEmpty) {
      totalBytes = await StorageService.getFolderSize(targetFolder);
    }
    task.downloadedBytes = totalBytes;

    if (!_isCancelled) {
      if (task.downloadedImages + task.skippedImages > 0 && task.failedImages == 0) {
        task.status = TaskStatus.completed;
        task.finishTime = DateTime.now();
        await _writeAlbumMetadata(targetFolder, item);
        onLog('图集下载完成: ${item.title} (新增${task.downloadedImages}张, 跳过${task.skippedImages}张)', 'success');
      } else if (task.failedImages > 0) {
        task.status = TaskStatus.failed;
        onLog('图集下载存在失败图片: ${item.title} (失败${task.failedImages}张)', 'error');
      }
    } else {
      task.status = TaskStatus.paused;
    }

    onTaskProgress?.call(task);
    return task;
  }
}
