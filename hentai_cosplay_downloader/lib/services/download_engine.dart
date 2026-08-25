import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import '../models/album_item.dart';
import '../models/app_config.dart';
import '../models/download_task.dart';
import '../models/video_item.dart';
import 'hc_api_service.dart';
import 'jable/decryptor.dart';
import 'storage_service.dart';
import 'video_api_service.dart';

typedef DownloadLogCallback = void Function(String message, String level);
typedef TaskProgressCallback = void Function(AlbumDownloadTask task);

const String kAlbumMetadataFilename = '.hc_album.json';

class DownloadEngine {
  final AppConfig config;
  final DownloadLogCallback onLog;
  final TaskProgressCallback? onTaskProgress;

  bool _isCancelled = false;
  CancelToken? _cancelToken;
  late final Dio _dio;

  DownloadEngine({
    required this.config,
    required this.onLog,
    this.onTaskProgress,
  }) {
    _cancelToken = CancelToken();
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
        final clean = config.customProxy.trim().replaceAll(RegExp(r'https?://|socks5?://'), '');
        if (config.customProxy.trim().startsWith('socks')) {
          client.findProxy = (uri) => 'SOCKS5 $clean; DIRECT';
        } else {
          client.findProxy = (uri) => 'PROXY $clean; DIRECT';
        }
      } else {
        client.findProxy = (uri) => 'DIRECT';
      }
      return client;
    };
    _dio.httpClientAdapter = adapter;
  }

  void cancel() {
    _isCancelled = true;
    _cancelToken?.cancel('用户已暂停下载');
  }

  /// Validate if file has valid image header magic bytes (JPEG, PNG, GIF, WEBP, BMP)
  static Future<bool> _isValidImageFile(File file) async {
    try {
      final len = await file.length();
      if (len < 12) return false;
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      await raf.close();
      if (header.length < 12) return false;

      // JPEG: FF D8 FF
      if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) return true;
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      if (header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) return true;
      // GIF: GIF87a / GIF89a
      if (header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46) return true;
      // WEBP: RIFF....WEBP
      if (header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 &&
          header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50) {
        return true;
      }
      // BMP: BM
      if (header[0] == 0x42 && header[1] == 0x4D) return true;
    } catch (_) {}
    return false;
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

  /// Write metadata file
  Future<void> _writeAlbumMetadata(String folderPath, AlbumItem item) async {
    try {
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
        'sourceType': item.sourceType.name,
        'item': item.rawData,
      };
      final file = File(p.join(folderPath, kAlbumMetadataFilename));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

      if (item.sourceType == MediaSourceType.mzt) {
        final mztFile = File(p.join(folderPath, kMztMetadataFilename));
        await mztFile.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      }
    } catch (_) {}
  }

  /// Download a single image with multi-domain fallback, retry, existence check, magic bytes validation, and atomic file write
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

    // 2. Build candidate URLs (handling MZT relative paths with proxy domains)
    final List<String> candidateUrls = [];
    if (originalUrl.startsWith('/')) {
      for (final domain in config.mztProxyDomains) {
        final cleanDomain = domain.trim().replaceAll(RegExp(r'/+$'), '');
        candidateUrls.add('$cleanDomain$originalUrl');
      }
    } else {
      candidateUrls.add(originalUrl);
    }

    final random = Random();

    // 3. Iterate through candidate URLs / proxy domains
    for (final targetUrl in candidateUrls) {
      if (_isCancelled) break;

      for (int i = 0; i < config.retryCount; i++) {
        if (_isCancelled) break;
        File? tempFile;

        try {
          tempFile = File('$savePath.tmp_${DateTime.now().microsecondsSinceEpoch}');
          if (await tempFile.exists()) await tempFile.delete();

          imageTask.status = ImageTaskStatus.downloading;

          int lastBytes = 0;
          final response = await _dio.download(
            targetUrl,
            tempFile.path,
            cancelToken: _cancelToken,
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
              headers: {
                if (targetUrl.contains('tgproxy') || targetUrl.contains('111404.xyz'))
                  'Referer': 'https://mzt.111404.xyz/'
                else
                  'Referer': '${HCApiService.kBaseUrl}/',
              },
              validateStatus: (status) => status != null && status < 500,
            ),
          );

          if (response.statusCode == 200) {
            if (await tempFile.exists() && await tempFile.length() > 0) {
              // Verify that downloaded file contains valid image magic bytes (not an HTML block page)
              final isValid = await _isValidImageFile(tempFile);
              if (isValid) {
                final targetFile = File(savePath);
                if (await targetFile.exists()) await targetFile.delete();
                await tempFile.rename(targetFile.path);
                imageTask.status = ImageTaskStatus.success;
                return ImageTaskStatus.success;
              } else {
                onLog('下载图片内容校验失败(非有效图片格式): ${p.basename(savePath)}', 'warn');
              }
            }
          } else if (response.statusCode == 404 && candidateUrls.length > 1) {
            // 404 indicates missing on this node, switch to next proxy domain immediately
            if (await tempFile.exists()) await tempFile.delete();
            onLog('节点返回404，切换备用节点: ${p.basename(savePath)}', 'warn');
            break;
          }
        } catch (e) {
          if (_isCancelled) break;
          if (i < config.retryCount - 1) {
            final delayMs = 600 + random.nextInt(1000);
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        } finally {
          if (tempFile != null && await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }
        }
      }

      if (candidateUrls.length > 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    imageTask.status = ImageTaskStatus.failed;
    imageTask.error = '单图下载失败';
    onLog('单图下载失败: ${p.basename(savePath)}', 'warn');
    return ImageTaskStatus.failed;
  }

  /// Process a video task with direct download, auto-organization, and companion metadata
  Future<AlbumDownloadTask> processVideo(
    AlbumDownloadTask task,
    String baseDir, {
    required void Function(int bytes) onBytesReceived,
  }) async {
    final item = task.albumItem;
    final videoBaseDir = p.join(baseDir, 'video');

    // 1. Determine target directory according to autoArchive
    String targetFolder;
    if (config.autoArchive) {
      final author = VideoItem.cleanArchiveSegment(item.author);
      targetFolder = p.join(videoBaseDir, author);
    } else {
      targetFolder = videoBaseDir;
    }
    _isCancelled = false;
    _cancelToken = CancelToken();

    final cleanTitle = VideoItem.cleanFilename(item.title);

    task.targetFolder = targetFolder;
    task.totalImages = 1;
    task.status = TaskStatus.downloading;
    task.startTime ??= DateTime.now();

    // 2. Check if already exists (.mp4 or .ts)
    for (final ext in ['mp4', 'ts', 'mkv', 'webm']) {
      final possibleFile = File(p.join(targetFolder, '$cleanTitle.$ext'));
      if (await possibleFile.exists() && await possibleFile.length() > 1024) {
        final size = await possibleFile.length();
        task.skippedImages = 1;
        task.downloadedImages = 0;
        task.failedImages = 0;
        task.downloadedBytes = size;
        task.totalBytes = size;
        task.status = TaskStatus.completed;
        task.finishTime = DateTime.now();
        onLog('已存在完整视频，自动跳过: ${item.title}', 'info');
        onTaskProgress?.call(task);
        return task;
      }
    }

    onTaskProgress?.call(task);

    // 3. Resolve video direct URL if needed
    String? directUrl = task.videoUrl;
    VideoItem? vDetail;
    if (directUrl == null || directUrl.isEmpty) {
      onLog('正在解析视频播放地址: ${item.title}', 'info');
      vDetail = await VideoApiService.fetchVideoDetail(
        VideoItem(
          title: item.title,
          slug: item.slug,
          detailUrl: item.detailUrl,
          coverUrl: item.coverUrl,
          date: item.date,
          author: item.author,
          tags: item.tags,
        ),
      );

      directUrl = vDetail?.videoUrl;
    }

    if (directUrl == null || directUrl.isEmpty) {
      task.status = TaskStatus.failed;
      task.errorMessage = '未能解析到视频源地址';
      onTaskProgress?.call(task);
      return task;
    }

    // 4. Determine file extension: .ts for HLS stream, .mp4 for progressive stream
    final isM3u8 = directUrl.contains('.m3u8');
    final videoExt = isM3u8 ? 'ts' : 'mp4';
    final videoFilePath = p.join(targetFolder, '$cleanTitle.$videoExt');
    final metaFilePath = p.join(targetFolder, '$cleanTitle.json');
    final coverFilePath = p.join(targetFolder, '$cleanTitle.jpg');

    final dir = Directory(targetFolder);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tempFilePath = '$videoFilePath.tmp';
    final tempFile = File(tempFilePath);
    if (await tempFile.exists()) await tempFile.delete();

    onLog('开始下载视频: ${item.title}', 'info');
    bool downloadSuccess = false;

    try {
      if (isM3u8) {
        downloadSuccess = await _downloadM3u8Video(
          m3u8Url: directUrl,
          targetVideoPath: videoFilePath,
          task: task,
          onBytesReceived: onBytesReceived,
        );
      } else {
        // Direct MP4 file download
        int lastBytes = 0;
        int lastProgressNotifyTime = 0;
        await _dio.download(
          directUrl,
          tempFilePath,
          cancelToken: _cancelToken,
          options: Options(headers: {'Referer': '${VideoApiService.kBaseUrl}/'}),
          onReceiveProgress: (received, total) {
            if (_isCancelled) return;
            final delta = received - lastBytes;
            if (delta > 0) {
              lastBytes = received;
              onBytesReceived(delta);
            }
            task.downloadedBytes = received;
            if (total > 0) {
              task.totalBytes = total;
            }
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressNotifyTime > 300 || (total > 0 && received >= total)) {
              lastProgressNotifyTime = now;
              onTaskProgress?.call(task);
            }
          },
        );

        if (await tempFile.exists() && await tempFile.length() > 1024) {
          final finalFile = File(videoFilePath);
          if (await finalFile.exists()) await finalFile.delete();
          await tempFile.rename(finalFile.path);
          downloadSuccess = true;
        }
      }
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    if (downloadSuccess) {
      task.downloadedImages = 1;
      task.status = TaskStatus.completed;
      task.finishTime = DateTime.now();
      try {
        final finalVideoFile = File(videoFilePath);
        if (await finalVideoFile.exists()) {
          task.downloadedBytes = await finalVideoFile.length();
        }
      } catch (_) {}

      // Save companion cover and metadata strictly matching the video
      try {
        final detail = vDetail;
        final coverToDownload = (detail?.coverUrl != null && detail!.coverUrl!.isNotEmpty)
            ? detail.coverUrl!
            : (item.coverUrl ?? '');

        if (coverToDownload.isNotEmpty) {
          await _dio.download(
            coverToDownload,
            coverFilePath,
            cancelToken: _cancelToken,
            options: Options(headers: {'Referer': '${VideoApiService.kBaseUrl}/'}),
          );
        }

        final metaPayload = {
          'title': (detail != null && detail.title.isNotEmpty) ? detail.title : item.title,
          'slug': item.slug,
          'author': (detail != null && detail.author.isNotEmpty) ? detail.author : item.author,
          'date': item.date,
          'duration': (detail != null && detail.duration.isNotEmpty) ? detail.duration : (task.duration ?? ''),
          'sourceUrl': item.detailUrl,
          'videoUrl': directUrl,
          'videoFile': p.basename(videoFilePath),
          'tags': (detail != null && detail.tags.isNotEmpty) ? detail.tags : item.tags,
          'saved_at': DateTime.now().toIso8601String(),
        };
        await File(metaFilePath).writeAsString(
          const JsonEncoder.withIndent('  ').convert(metaPayload),
        );
      } catch (_) {}

      onLog('视频下载完成: ${item.title}', 'success');
      onTaskProgress?.call(task);
      return task;
    }

    task.status = TaskStatus.failed;
    task.errorMessage = '视频下载失败，请检查网络或配置代理';
    onLog('视频下载失败: ${item.title}', 'error');
    onTaskProgress?.call(task);
    return task;
  }

  /// Download M3U8 HLS stream by fetching playlist and concatenating TS video segments
  Future<bool> _downloadM3u8Video({
    required String m3u8Url,
    required String targetVideoPath,
    required AlbumDownloadTask task,
    required void Function(int bytes) onBytesReceived,
  }) async {
    File? tempFile;
    IOSink? sink;
    try {
      // 1. Fetch m3u8 playlist text
      final resp = await _dio.get(
        m3u8Url,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': '${VideoApiService.kBaseUrl}/'},
        ),
      );

      if (resp.statusCode != 200 || resp.data == null) {
        return false;
      }

      final m3u8Text = resp.data.toString();
      final lines = m3u8Text.split(RegExp(r'\r?\n'));
      final List<String> segmentUrls = [];

      final baseUri = Uri.parse(m3u8Url);
      Uint8List? aesKeyBytes;
      Uint8List? aesIvBytes;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('#EXT-X-KEY')) {
          // Parse AES-128 Key: #EXT-X-KEY:METHOD=AES-128,URI="...",IV=0x...
          try {
            final uriMatch = RegExp(r'URI=["\x27]([^"\x27]+)["\x27]').firstMatch(trimmed);
            if (uriMatch != null) {
              final rawKeyUri = uriMatch.group(1)!;
              final keyUri = rawKeyUri.startsWith('http')
                  ? rawKeyUri
                  : baseUri.resolve(rawKeyUri).toString();
              final keyResp = await _dio.get<List<int>>(
                keyUri,
                cancelToken: _cancelToken,
                options: Options(
                  responseType: ResponseType.bytes,
                  headers: {'Referer': '${VideoApiService.kBaseUrl}/'},
                ),
              );
              if (keyResp.statusCode == 200 && keyResp.data != null && keyResp.data!.length == 16) {
                aesKeyBytes = Uint8List.fromList(keyResp.data!);
              }
            }

            final ivMatch = RegExp(r'IV=0x([0-9a-fA-F]+)').firstMatch(trimmed);
            if (ivMatch != null) {
              final hexStr = ivMatch.group(1)!;
              final ivList = <int>[];
              for (var i = 0; i < hexStr.length; i += 2) {
                ivList.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
              }
              while (ivList.length < 16) {
                ivList.insert(0, 0);
              }
              aesIvBytes = Uint8List.fromList(ivList.sublist(0, 16));
            }
          } catch (keyErr) {
            onLog('解析 HLS 密钥出错: $keyErr', 'warning');
          }
          continue;
        }

        if (trimmed.startsWith('#')) continue;

        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          segmentUrls.add(trimmed);
        } else {
          final resolved = baseUri.resolve(trimmed).toString();
          segmentUrls.add(resolved);
        }
      }

      if (segmentUrls.isEmpty) return false;

      tempFile = File('$targetVideoPath.tmp');
      if (await tempFile.exists()) await tempFile.delete();
      sink = tempFile.openWrite(mode: FileMode.writeOnlyAppend);

      int totalDownloadedBytes = 0;
      int completedSegments = 0;
      int lastProgressNotifyTime = 0;

      for (int i = 0; i < segmentUrls.length; i++) {
        if (_isCancelled) {
          return false;
        }

        final segUrl = segmentUrls[i];
        List<int>? segBytes;

        for (int retry = 0; retry < config.retryCount; retry++) {
          if (_isCancelled) break;
          try {
            final segResp = await _dio.get<List<int>>(
              segUrl,
              cancelToken: _cancelToken,
              options: Options(
                responseType: ResponseType.bytes,
                headers: {'Referer': '${VideoApiService.kBaseUrl}/'},
              ),
            );

            if (segResp.statusCode == 200 && segResp.data != null) {
              segBytes = segResp.data!;
              break;
            }
          } catch (_) {
            if (_isCancelled) break;
            if (retry < config.retryCount - 1) {
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }

        if (segBytes == null || _isCancelled) {
          return false;
        }

        // Decrypt if AES-128 key is configured
        Uint8List writeBytes = Uint8List.fromList(segBytes);
        if (aesKeyBytes != null) {
          Uint8List segIv = aesIvBytes ?? Uint8List(16);
          if (aesIvBytes == null) {
            final ivData = ByteData(16);
            ivData.setUint64(8, i + 1, Endian.big);
            segIv = ivData.buffer.asUint8List();
          }
          try {
            writeBytes = await Decryptor.decryptSegmentAsync(writeBytes, aesKeyBytes, segIv);
          } catch (decErr) {
            onLog('解密分片 #$i 失败: $decErr', 'warning');
          }
        }

        sink.add(writeBytes);
        totalDownloadedBytes += writeBytes.length;
        onBytesReceived(writeBytes.length);
        completedSegments++;

        if (completedSegments % 10 == 0) {
          await sink.flush();
        }

        task.downloadedBytes = totalDownloadedBytes;
        final avgSeg = totalDownloadedBytes / completedSegments;
        task.totalBytes = (avgSeg * segmentUrls.length).toInt();

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastProgressNotifyTime > 300 || completedSegments == segmentUrls.length) {
          lastProgressNotifyTime = now;
          onTaskProgress?.call(task);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await tempFile.exists() && await tempFile.length() > 1024) {
        final finalFile = File(targetVideoPath);
        if (await finalFile.exists()) await finalFile.delete();
        await tempFile.rename(finalFile.path);
        return true;
      }
    } catch (e) {
      return false;
    } finally {
      if (sink != null) {
        try {
          await sink.flush();
          await sink.close();
        } catch (_) {}
      }
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
    return false;
  }

  /// Process an entire album task with image concurrency and smart skip detection
  Future<AlbumDownloadTask> processAlbum(
    AlbumDownloadTask task,
    String baseDir, {
    required void Function(int bytes) onBytesReceived,
  }) async {
    _isCancelled = false;
    _cancelToken = CancelToken();

    // If this is a video download task, forward to processVideo
    if (task.isVideo) {
      return processVideo(task, baseDir, onBytesReceived: onBytesReceived);
    }

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

    // Prepare or reuse image tasks for breakpoint resume
    if (task.imageTasks.isEmpty || task.imageTasks.length != item.imageUrls.length) {
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
    }

    task.downloadedImages = task.imageTasks.where((e) => e.status == ImageTaskStatus.success).length;
    task.skippedImages = task.imageTasks.where((e) => e.status == ImageTaskStatus.skipped).length;
    task.failedImages = 0;

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
      if (imgTask.status == ImageTaskStatus.success || imgTask.status == ImageTaskStatus.skipped) {
        continue;
      }

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
