import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/jable_task.dart';
import '../config_service.dart';
import 'api_client.dart';
import 'cf_cookie_harvester.dart';
import 'merger.dart';
import 'persistent_chromium_tunnel.dart';
import 'scrapers/base_scraper.dart';
import 'scrapers/jable_scraper.dart';
import 'scrapers/missav_scraper.dart';
import 'scrapers/supjav_scraper.dart';
import 'segment_downloader.dart';

class _StreamVariant {
  final int height;
  final String url;
  _StreamVariant({required this.height, required this.url});
}

class _HlsPlaylistData {
  final List<String> segments;
  final String? keyUrl;
  final Uint8List? keyIv;
  final int mediaSequence;

  _HlsPlaylistData({
    required this.segments,
    this.keyUrl,
    this.keyIv,
    required this.mediaSequence,
  });
}

class JableDownloadEngine {
  final JableDownloadTask task;
  final void Function(int bytes) onBytesReceived;
  final void Function(JableDownloadTask task) onTaskUpdated;

  bool _isCancelled = false;
  CancelToken? _cancelToken;

  JableDownloadEngine({
    required this.task,
    required this.onBytesReceived,
    required this.onTaskUpdated,
  });

  void cancel() {
    _isCancelled = true;
    task.status = JableDownloadStatus.cancelled;
    _cancelToken?.cancel("User cancelled");
  }

  BaseScraper? getScraper(String url) {
    if (url.contains('jable.tv') || url.contains('fs1.app')) {
      return JableScraper();
    } else if (url.contains('missav.')) {
      return MissAVScraper();
    } else if (url.contains('supjav.') || url.contains('supremejav.')) {
      return SupJavScraper();
    }
    return null;
  }

  static String sanitizeFileName(String name) {
    var clean = name
        .replaceAll(RegExp(r'[\r\n\t\x00-\x1f\x7f\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length > 70) {
      clean = clean.substring(0, 70).trim();
    }
    if (clean.isEmpty) {
      clean = "jable_video_${DateTime.now().millisecondsSinceEpoch}";
    }
    return clean;
  }

  static String _resolveHlsUrl(Uri baseUri, String targetUrl) {
    final cleanTarget = targetUrl.trim();
    if (cleanTarget.startsWith('http://') || cleanTarget.startsWith('https://')) {
      return cleanTarget;
    }
    final resolved = baseUri.resolve(cleanTarget);
    if (!resolved.hasQuery && baseUri.hasQuery) {
      return resolved.replace(query: baseUri.query).toString();
    }
    return resolved.toString();
  }

  Future<String> _resolveQuality(String masterUrl, String siteName, {Map<String, String>? extraHeaders}) async {
    try {
      final headers = ApiClient().getHeadersForSite(siteName, masterUrl);
      if (extraHeaders != null) {
        headers.addAll(extraHeaders);
      }
      final host = Uri.parse(masterUrl).host;
      final isCdn = !host.contains('missav') && !host.contains('jable') && !host.contains('fs1.app') && !host.contains('supjav');
      if (isCdn) {
        headers.remove('Cookie');
        headers.remove('cookie');
        final rawReferer = extraHeaders?['Referer'] ?? "https://${ApiClient().getActiveHost(siteName)}/";
        final referer = rawReferer.split('#').first;
        final rawOrigin = extraHeaders?['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');
        final origin = rawOrigin.split('#').first;
        headers['Referer'] = referer;
        headers['Origin'] = origin;
        headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
      }

      final dio = ApiClient().dio;
      String content = "";
      try {
        final response = await dio.get(
          masterUrl,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        content = response.data?.toString() ?? "";
      } catch (_) {
        try {
          final jsText = await PersistentChromiumTunnel.fetchText(masterUrl, siteName: siteName, headers: headers);
          if (jsText != null && jsText.isNotEmpty) {
            content = jsText;
          } else {
            content = await CfCookieHarvester.fetchTextViaJs(masterUrl, siteName: siteName, headers: headers);
          }
        } catch (_) {}
      }
      
      if (!content.contains('#EXT-X-STREAM-INF')) {
        return masterUrl;
      }

      final lines = const LineSplitter().convert(content);
      final List<_StreamVariant> variants = [];
      final baseUri = Uri.parse(masterUrl);
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
          final resHeight = resMatch != null ? int.parse(resMatch.group(2)!) : 0;
          
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
              final subUrl = _resolveHlsUrl(baseUri, nextLine);
              variants.add(_StreamVariant(height: resHeight, url: subUrl));
            }
          }
        }
      }

      if (variants.isEmpty) return masterUrl;

      final config = ConfigService.loadConfig();
      final pref = config.jableResolutionPref;
      
      variants.sort((a, b) => b.height.compareTo(a.height));

      if (pref == 'highest') {
        return variants.first.url;
      } else if (pref == 'lowest') {
        return variants.last.url;
      } else {
        final targetHeight = int.tryParse(pref.replaceAll('p', '')) ?? 1080;
        _StreamVariant? bestMatch;
        for (final v in variants) {
          if (v.height <= targetHeight) {
            bestMatch = v;
            break;
          }
        }
        return bestMatch?.url ?? variants.last.url;
      }
    } catch (_) {
      return masterUrl;
    }
  }

  Future<_HlsPlaylistData> _parseHlsPlaylist(String playlistUrl, String siteName, {Map<String, String>? extraHeaders}) async {
    final headers = ApiClient().getHeadersForSite(siteName, playlistUrl);
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    final host = Uri.parse(playlistUrl).host;
    final isCdn = !host.contains('missav') && !host.contains('jable') && !host.contains('fs1.app') && !host.contains('supjav');
    if (isCdn) {
      headers.remove('Cookie');
      headers.remove('cookie');
      final rawReferer = extraHeaders?['Referer'] ?? "https://${ApiClient().getActiveHost(siteName)}/";
      final referer = rawReferer.split('#').first;
      final rawOrigin = extraHeaders?['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');
      final origin = rawOrigin.split('#').first;
      headers['Referer'] = referer;
      headers['Origin'] = origin;
      headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
    }

    final dio = ApiClient().dio;
    String content = "";

    final headerCandidates = <Map<String, String>>[
      Map<String, String>.from(headers),
    ];
    final currentRef = headers['Referer'];
    if (currentRef != null && currentRef.isNotEmpty) {
      final refUri = Uri.tryParse(currentRef);
      if (refUri != null && refUri.hasScheme) {
        final rootRef = "${refUri.scheme}://${refUri.host}/";
        if (rootRef != currentRef) {
          final h2 = Map<String, String>.from(headers);
          h2['Referer'] = rootRef;
          headerCandidates.add(h2);
        }
      }
    }
    final siteRoot = "https://${ApiClient().getActiveHost(siteName)}/";
    if (currentRef != siteRoot) {
      final h3 = Map<String, String>.from(headers);
      h3['Referer'] = siteRoot;
      h3['Origin'] = siteRoot.replaceAll(RegExp(r'/+$'), '');
      headerCandidates.add(h3);
    }
    final h4 = Map<String, String>.from(headers);
    h4.remove('Referer');
    h4.remove('Origin');
    headerCandidates.add(h4);

    for (final candHeaders in headerCandidates) {
      try {
        final response = await dio.get(
          playlistUrl,
          options: Options(
            headers: candHeaders,
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          final text = response.data.toString();
          if (text.contains('#EXTM3U')) {
            content = text;
            break;
          }
        }
      } catch (_) {}
    }

    if (content.isEmpty) {
      try {
        final jsText = await PersistentChromiumTunnel.fetchText(playlistUrl, siteName: siteName, headers: headers);
        if (jsText != null && jsText.contains('#EXTM3U')) {
          content = jsText;
        } else {
          final fallbackText = await CfCookieHarvester.fetchTextViaJs(playlistUrl, siteName: siteName, headers: headers);
          if (fallbackText.contains('#EXTM3U')) {
            content = fallbackText;
          }
        }
      } catch (_) {}
    }
    
    if (!content.contains('#EXTM3U')) {
      throw Exception("无法解析有效 M3U8 播放列表: $playlistUrl");
    }

    if (content.contains('#EXT-X-STREAM-INF')) {
      final lines = const LineSplitter().convert(content);
      final List<_StreamVariant> variants = [];
      final baseUri = Uri.parse(playlistUrl);
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
          final resHeight = resMatch != null ? int.parse(resMatch.group(2)!) : 0;
          
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
              final subUrl = _resolveHlsUrl(baseUri, nextLine);
              variants.add(_StreamVariant(height: resHeight, url: subUrl));
            }
          }
        }
      }

      if (variants.isNotEmpty) {
        final config = ConfigService.loadConfig();
        final pref = config.jableResolutionPref;
        variants.sort((a, b) => b.height.compareTo(a.height));

        String variantUrl;
        if (pref == 'highest') {
          variantUrl = variants.first.url;
        } else if (pref == 'lowest') {
          variantUrl = variants.last.url;
        } else {
          final targetHeight = int.tryParse(pref.replaceAll('p', '')) ?? 1080;
          _StreamVariant? bestMatch;
          for (final v in variants) {
            if (v.height <= targetHeight) {
              bestMatch = v;
              break;
            }
          }
          variantUrl = bestMatch?.url ?? variants.last.url;
        }
        return _parseHlsPlaylist(variantUrl, siteName, extraHeaders: extraHeaders);
      }
    }
    
    final lines = const LineSplitter().convert(content);
    final List<String> segments = [];
    String? keyUrl;
    Uint8List? keyIv;
    int mediaSequence = 0;

    final baseUri = Uri.parse(playlistUrl);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSequence = int.tryParse(line.split(':').last) ?? 0;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        final methodMatch = RegExp(r'METHOD=([^,\s]+)').firstMatch(line);
        final method = methodMatch?.group(1) ?? "";
        
        if (method == 'AES-128') {
          final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(line);
          if (uriMatch != null) {
            final rawUri = uriMatch.group(1)!;
            keyUrl = _resolveHlsUrl(baseUri, rawUri);
          }
          
          final ivMatch = RegExp(r'IV=0x([0-9a-fA-F]+)').firstMatch(line);
          if (ivMatch != null) {
            final ivHex = ivMatch.group(1)!.padLeft(32, '0');
            final ivBytes = Uint8List(16);
            for (int j = 0; j < 16; j++) {
              ivBytes[j] = int.parse(ivHex.substring(j * 2, j * 2 + 2), radix: 16);
            }
            keyIv = ivBytes;
          }
        }
      } else if (line.startsWith('#EXTINF:')) {
        for (int k = i + 1; k < lines.length; k++) {
          final nextLine = lines[k].trim();
          if (nextLine.isNotEmpty) {
            if (!nextLine.startsWith('#')) {
              final segmentUrl = _resolveHlsUrl(baseUri, nextLine);
              segments.add(segmentUrl);
              break;
            }
          }
        }
      }
    }

    return _HlsPlaylistData(
      segments: segments,
      keyUrl: keyUrl,
      keyIv: keyIv,
      mediaSequence: mediaSequence,
    );
  }

  Future<void> run() async {
    final scraper = getScraper(task.url);
    if (scraper == null) {
      task.status = JableDownloadStatus.failed;
      task.errorMsg = "不支持的网站链接";
      onTaskUpdated(task);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final taskTempFolder = Directory("${tempDir.path}/jable_dl_${task.id}");
    if (!await taskTempFolder.exists()) {
      await taskTempFolder.create(recursive: true);
    }

    final config = ConfigService.loadConfig();
    String finalDestPath = p.join(config.savePath, 'jabletv');
    var jableDir = Directory(finalDestPath);
    try {
      if (!await jableDir.exists()) {
        await jableDir.create(recursive: true);
      }
    } catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      finalDestPath = p.join(docDir.path, 'jabletv');
      jableDir = Directory(finalDestPath);
      await jableDir.create(recursive: true);
    }
    task.destPath = finalDestPath;

    try {
      PersistentChromiumTunnel.retain();
      task.status = JableDownloadStatus.downloading;
      onTaskUpdated(task);

      // 1. Scraping video page to find m3u8 url
      final detail = await scraper.parseVideoDetail(task.url);
      
      if (_isCancelled || task.status == JableDownloadStatus.cancelled) return;

      if (detail.title.isNotEmpty) {
        task.name = sanitizeFileName(detail.title);
      }
      if (detail.imageUrl.isNotEmpty) {
        task.thumbnailUrl = detail.imageUrl;
      }
      onTaskUpdated(task);

      bool isDirectMp4 = false;
      final cleanUrlLower = detail.m3u8Url.split('?').first.toLowerCase();
      if (cleanUrlLower.endsWith('.mp4') ||
          (detail.m3u8Url.contains('.mp4') && !detail.m3u8Url.contains('.m3u8'))) {
        isDirectMp4 = true;
      } else if (!detail.m3u8Url.contains('.m3u8')) {
        // Probe whether it is actually an M3U8 playlist or a direct binary stream
        try {
          final hlsData = await _parseHlsPlaylist(detail.m3u8Url, scraper.siteName, extraHeaders: detail.headers);
          if (hlsData.segments.isEmpty) {
            isDirectMp4 = true;
          }
        } catch (_) {
          // If probing failed with non-playlist error, assume direct binary stream
          isDirectMp4 = true;
        }
      }

      if (isDirectMp4) {
        final dio = ApiClient().dio;
        final saveFile = File("$finalDestPath/${task.name}.mp4");
        
        _cancelToken = CancelToken();
        int lastBytes = 0;
        await dio.download(
          detail.m3u8Url,
          saveFile.path,
          cancelToken: _cancelToken,
          options: Options(headers: detail.headers),
          onReceiveProgress: (received, total) {
            if (_isCancelled || task.status == JableDownloadStatus.cancelled) {
              return;
            }
            final delta = received - lastBytes;
            if (delta > 0) {
              lastBytes = received;
              onBytesReceived(delta);
            }
            if (total > 0) {
              task.progress = (received / total) * 100;
              task.totalSegments = (total / (1024 * 1024)).ceil();
              task.completedSegments = (received / (1024 * 1024)).floor();
              onTaskUpdated(task);
            }
          },
        );

        // Header validation: Ensure downloaded file is not an M3U8 text playlist mistakenly saved as MP4
        bool isBogusM3u8Text = false;
        if (await saveFile.exists() && await saveFile.length() < 64 * 1024) {
          try {
            final headerBytes = await saveFile.openRead(0, 32).first;
            final headerStr = utf8.decode(headerBytes, allowMalformed: true);
            if (headerStr.contains('#EXTM3U')) {
              isBogusM3u8Text = true;
              await saveFile.delete();
            }
          } catch (_) {}
        }

        if (!isBogusM3u8Text && await saveFile.exists() && await saveFile.length() > 0) {
          if (detail.imageUrl.isNotEmpty) {
            try {
              await dio.download(
                detail.imageUrl,
                "$finalDestPath/${task.name}.jpg",
                options: Options(headers: detail.headers),
              );
            } catch (_) {}
          }

          final metaPayload = {
            'title': task.name,
            'url': task.url,
            'thumbnail': task.thumbnailUrl,
            'duration': task.duration,
            'siteName': task.siteName,
            'downloadedAt': DateTime.now().toIso8601String(),
          };
          await File("$finalDestPath/${task.name}.json").writeAsString(
            const JsonEncoder.withIndent('  ').convert(metaPayload),
          );

          task.status = JableDownloadStatus.completed;
          task.progress = 100.0;
          task.speed = "0 KB/s";
          task.finishedAt = DateTime.now();
          onTaskUpdated(task);
          return;
        }
      }

      // 2. Fetch M3U8 Master Playlist & resolve preferred quality
      final m3u8Url = await _resolveQuality(detail.m3u8Url, scraper.siteName, extraHeaders: detail.headers);

      // 3. Parse segments and HLS keys
      final hlsData = await _parseHlsPlaylist(m3u8Url, scraper.siteName, extraHeaders: detail.headers);
      if (_isCancelled || task.status == JableDownloadStatus.cancelled) return;

      final segments = hlsData.segments;
      task.totalSegments = segments.length;
      onTaskUpdated(task);

      if (segments.isEmpty) {
        throw Exception("在 M3U8 流中未找到任何视频切片");
      }

      // 4. Download decryption key if HLS is encrypted
      Uint8List? keyData;
      if (hlsData.keyUrl != null) {
        final keyHeaders = ApiClient().getHeadersForSite(scraper.siteName, hlsData.keyUrl!);
        final keyHost = Uri.parse(hlsData.keyUrl!).host;
        final isKeyCdn = !keyHost.contains('missav') && !keyHost.contains('jable') && !keyHost.contains('fs1.app') && !keyHost.contains('supjav');
        if (isKeyCdn) {
          keyHeaders.remove('Cookie');
          keyHeaders.remove('cookie');
          final referer = detail.headers['Referer'] ?? "https://${ApiClient().getActiveHost(scraper.siteName)}/";
          final origin = detail.headers['Origin'] ?? referer.replaceAll(RegExp(r'/+$'), '');
          keyHeaders['Referer'] = referer;
          keyHeaders['Origin'] = origin;
        }
        keyData = Uint8List.fromList(
          await ApiClient().downloadBytes(scraper.siteName, hlsData.keyUrl!, extraHeaders: keyHeaders),
        );
      }

      // 5. Concurrent segment downloading using worker pool
      final List<String> segmentPaths = List.generate(
        segments.length,
        (i) => "${taskTempFolder.path}/${i.toString().padLeft(6, '0')}.ts",
      );
      int completedCount = 0;
      int failedSegmentsCount = 0;
      int nextSegmentIndex = 0;
      const int workerCount = 5;

      Future<void> downloadWorker() async {
        while (true) {
          if (_isCancelled || task.status == JableDownloadStatus.cancelled) break;
          final int i = nextSegmentIndex++;
          if (i >= segments.length) break;

          final segmentUrl = segments[i];
          final segmentPath = segmentPaths[i];

          Uint8List? ivBytes;
          if (keyData != null) {
            if (hlsData.keyIv != null) {
              ivBytes = hlsData.keyIv!;
            } else {
              final seq = hlsData.mediaSequence + i;
              final bd = ByteData(16);
              bd.setUint64(8, seq);
              ivBytes = bd.buffer.asUint8List();
            }
          }

          final segmentHeaders = ApiClient().getHeadersForSite(scraper.siteName, segmentUrl);
          if (detail.headers['Referer'] != null && detail.headers['Referer']!.isNotEmpty) {
            segmentHeaders['Referer'] = detail.headers['Referer']!;
          }
          if (detail.headers['Origin'] != null && detail.headers['Origin']!.isNotEmpty) {
            segmentHeaders['Origin'] = detail.headers['Origin']!;
          }
          final segHost = Uri.parse(segmentUrl).host;
          final isCdn = !segHost.contains('missav') && !segHost.contains('jable') && !segHost.contains('fs1.app') && !segHost.contains('supjav');
          if (isCdn) {
            segmentHeaders.remove('Cookie');
            segmentHeaders.remove('cookie');
          }

          final downloadedBytes = await SegmentDownloader.downloadSegment(
            url: segmentUrl,
            savePath: segmentPath,
            headers: segmentHeaders,
            decryptKey: keyData,
            decryptIv: ivBytes,
            siteName: scraper.siteName,
          );

          if (downloadedBytes < 0) {
            if (_isCancelled || task.status == JableDownloadStatus.cancelled) break;
            failedSegmentsCount++;
          }

          if (!_isCancelled && task.status != JableDownloadStatus.cancelled) {
            completedCount++;
            task.completedSegments = completedCount;
            task.progress = (completedCount / segments.length) * 100;
            if (downloadedBytes > 0) {
              onBytesReceived(downloadedBytes);
            }
            onTaskUpdated(task);
          }
        }
      }

      final workers = List.generate(
        workerCount.clamp(1, segments.length),
        (_) => downloadWorker(),
      );
      await Future.wait(workers);

      if (_isCancelled || task.status == JableDownloadStatus.cancelled) {
        return;
      }

      if (failedSegmentsCount > 3 || (failedSegmentsCount > 0 && failedSegmentsCount >= segments.length * 0.05)) {
        throw Exception("视频分片下载失败过多 ($failedSegmentsCount/${segments.length})，下载中止");
      }

      // 6. Merging & Remuxing
      task.status = JableDownloadStatus.merging;
      onTaskUpdated(task);

      final finalMp4File = "$finalDestPath/${task.name}.mp4";

      final mergeResult = await Merger.mergeAndRemux(
        tempSegmentPaths: segmentPaths,
        outputMp4Path: finalMp4File,
        onProgress: (_) {},
      );

      if (!mergeResult.success) {
        throw Exception(mergeResult.error ?? "视频分片合并失败");
      }

      final resolvedMp4File = mergeResult.finalPath ?? finalMp4File;
      final resolvedDestPath = File(resolvedMp4File).parent.path;

      // 7. Cleanup task directories
      try {
        if (await taskTempFolder.exists()) {
          await taskTempFolder.delete(recursive: true);
        }
      } catch (_) {}

      // Save cover artwork
      if (detail.imageUrl.isNotEmpty) {
        try {
          final coverFile = File("$resolvedDestPath/${task.name}.jpg");
          if (!await coverFile.exists()) {
            final imgBytes = await ApiClient().downloadBytes(
              scraper.siteName,
              detail.imageUrl,
              extraHeaders: detail.headers,
            );
            if (imgBytes.isNotEmpty) {
              await coverFile.writeAsBytes(imgBytes);
            }
          }
        } catch (_) {}
      }

      // Write companion JSON metadata
      final metaPayload = {
        'title': task.name,
        'url': task.url,
        'thumbnail': task.thumbnailUrl,
        'duration': task.duration,
        'siteName': task.siteName,
        'downloadedAt': DateTime.now().toIso8601String(),
      };
      await File("$resolvedDestPath/${task.name}.json").writeAsString(
        const JsonEncoder.withIndent('  ').convert(metaPayload),
      );

      task.status = JableDownloadStatus.completed;
      task.progress = 100.0;
      task.destPath = resolvedDestPath;
      task.finishedAt = DateTime.now();
      onTaskUpdated(task);
    } catch (e) {
      if (!_isCancelled && task.status != JableDownloadStatus.cancelled) {
        task.status = JableDownloadStatus.failed;
        task.errorMsg = e.toString();
        onTaskUpdated(task);
      }
    } finally {
      PersistentChromiumTunnel.release();
    }
  }
}
