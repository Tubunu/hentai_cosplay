import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/pack_item.dart';

typedef DownloadLogCallback = void Function(String message, String level);
typedef TaskProgressCallback = void Function(PackDownloadTask task);

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
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://mzt.111404.xyz/',
          'Connection': 'keep-alive',
        },
      ),
    );
  }

  void cancel() {
    _isCancelled = true;
  }

  /// Check if all images exist in target folder
  Future<bool> _allImagesExist(String folderPath, List<String> urls) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return false;

    for (int i = 0; i < urls.length; i++) {
      final ext = PackItem.resolveExt(urls[i]);
      final filePath = p.join(folderPath, '${i + 1}.$ext');
      final file = File(filePath);
      if (!await file.exists()) return false;
      if (await file.length() == 0) return false;
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

  /// Find all potential directory locations for a pack, including archived ones
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
  Future<MapEntry<String, bool>> _selectPackFolder(String baseDir, String folderName, List<String> urls) async {
    final candidates = await _findCandidateFolders(baseDir, folderName);
    // 1. Check if any candidate has all images downloaded
    for (final folder in candidates) {
      if (await _allImagesExist(folder, urls)) {
        return MapEntry(folder, true);
      }
    }
    // 2. Check if any candidate has partial images
    for (final folder in candidates) {
      if (await _hasAnyImages(folder)) {
        return MapEntry(folder, false);
      }
    }
    return MapEntry(p.join(baseDir, folderName), false);
  }

  /// Write .mzt_pack.json metadata file
  Future<void> _writePackMetadata(String folderPath, PackItem item) async {
    try {
      final file = File(p.join(folderPath, kPackMetadataFilename));
      final payload = {
        'saved_at': DateTime.now().toIso8601String(),
        'title': item.title,
        'item': item.rawData,
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    } catch (_) {}
  }

  /// Download a single image with multi-domain fallback and retry
  Future<ImageTaskStatus> downloadImage({
    required String originalUrl,
    required String savePath,
    required ImageDownloadTask imageTask,
    required void Function(int bytes) onBytesReceived,
  }) async {
    final file = File(savePath);

    // 1. Check if already exists
    if (await file.exists()) {
      final len = await file.length();
      if (len > 0) {
        imageTask.status = ImageTaskStatus.skipped;
        imageTask.downloadedBytes = len;
        imageTask.totalBytes = len;
        onLog('已存在跳过: ${p.basename(savePath)}', 'info');
        return ImageTaskStatus.skipped;
      } else {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    if (_isCancelled) {
      imageTask.status = ImageTaskStatus.failed;
      return ImageTaskStatus.failed;
    }

    // 2. Build candidate URLs
    final List<String> candidateUrls = [];
    if (originalUrl.startsWith('/')) {
      for (final domain in config.proxyDomains) {
        final cleanDomain = domain.trim().replaceAll(RegExp(r'/+$'), '');
        candidateUrls.add('$cleanDomain$originalUrl');
      }
    } else {
      candidateUrls.add(originalUrl);
    }

    final random = Random();

    // 3. Iterate through candidate proxy domains
    for (final targetUrl in candidateUrls) {
      if (_isCancelled) break;

      for (int i = 0; i < config.retryCount; i++) {
        if (_isCancelled) break;

        try {
          final tempFile = File('$savePath.tmp_${DateTime.now().microsecondsSinceEpoch}');
          if (await tempFile.exists()) await tempFile.delete();

          imageTask.status = ImageTaskStatus.downloading;

          int lastBytes = 0;
          final response = await _dio.download(
            targetUrl,
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
              if (await file.exists()) await file.delete();
              await tempFile.rename(file.path);
              imageTask.status = ImageTaskStatus.success;
              return ImageTaskStatus.success;
            }
          } else if (response.statusCode == 404) {
            // 404 indicates resource is missing on this node, switch to next domain immediately
            if (await tempFile.exists()) await tempFile.delete();
            onLog('节点返回404，切换备用节点: ${p.basename(savePath)}', 'warn');
            break;
          }

          if (await tempFile.exists()) await tempFile.delete();
        } catch (e) {
          if (i < config.retryCount - 1) {
            final delayMs = 800 + random.nextInt(1200);
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    imageTask.status = ImageTaskStatus.failed;
    imageTask.error = '所有代理节点均下载失败';
    onLog('下载彻底失败: ${p.basename(savePath)}', 'error');
    return ImageTaskStatus.failed;
  }

  /// Process a single pack task with image concurrency and smart folder selection
  Future<PackDownloadTask> processSinglePack(
    PackDownloadTask task,
    String baseDir, {
    required void Function(int bytes) onBytesReceived,
  }) async {
    final item = task.packItem;
    final folderName = PackItem.cleanFilename(item.title);

    // Smartly find candidate folder (root or archive/<author>/<pack>)
    final selectedFolderResult = await _selectPackFolder(baseDir, folderName, item.urls);
    final targetFolder = selectedFolderResult.key;
    final isPackComplete = selectedFolderResult.value;
    final dir = Directory(targetFolder);

    task.targetFolder = targetFolder;
    task.totalImages = item.urls.length;
    task.status = TaskStatus.downloading;
    task.startTime ??= DateTime.now();

    // Reconstruct image tasks with the selected folder
    task.imageTasks.clear();
    for (int i = 0; i < item.urls.length; i++) {
      final ext = PackItem.resolveExt(item.urls[i]);
      final savePath = p.join(targetFolder, '${i + 1}.$ext');
      task.imageTasks.add(
        ImageDownloadTask(
          index: i + 1,
          originalUrl: item.urls[i],
          savePath: savePath,
        ),
      );
    }

    onTaskProgress?.call(task);

    // 1. Pack level skip check (if all images exist in root or archive)
    if (isPackComplete) {
      task.skippedImages = item.urls.length;
      task.downloadedImages = 0;
      task.failedImages = 0;
      task.status = TaskStatus.completed;
      task.finishTime = DateTime.now();
      for (final imgTask in task.imageTasks) {
        imgTask.status = ImageTaskStatus.skipped;
      }
      onLog('已下载完整图包，跳过: ${item.title} (${item.urls.length}张)', 'info');
      onTaskProgress?.call(task);
      return task;
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

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

    if (!_isCancelled) {
      await _writePackMetadata(targetFolder, item);
      task.status = (task.failedImages > 0 && task.downloadedImages == 0 && task.skippedImages == 0)
          ? TaskStatus.failed
          : TaskStatus.completed;
    } else {
      task.status = TaskStatus.paused;
    }

    task.finishTime = DateTime.now();
    onTaskProgress?.call(task);
    return task;
  }
}
