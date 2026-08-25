import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'decryptor.dart';
import 'persistent_chromium_tunnel.dart';

class SegmentDownloader {
  /// Downloads, decrypts, and cleans one TS segment.
  /// Returns downloaded byte count on success, or -1 on failure.
  static Future<int> downloadSegment({
    required String url,
    required String savePath,
    required Map<String, String> headers,
    required Uint8List? decryptKey,
    required Uint8List? decryptIv,
    required String siteName,
    int maxRetries = 4,
  }) async {
    final dio = ApiClient().dio;
    final file = File(savePath);
    final partFile = File('$savePath.part');
    
    // Check if this segment is already on disk (supports resume downloads)
    if (await file.exists()) {
      final len = await file.length();
      if (len > 0) return len;
      try {
        await file.delete();
      } catch (_) {}
    }
    
    final cleanHeaders = Map<String, String>.from(headers);
    if (cleanHeaders.containsKey('Referer')) {
      cleanHeaders['Referer'] = cleanHeaders['Referer']!.split('#').first;
    }
    if (cleanHeaders.containsKey('Origin')) {
      cleanHeaders['Origin'] = cleanHeaders['Origin']!.split('#').first;
    }
    final host = Uri.parse(url).host;
    final isTiktok = host.contains('tiktokcdn.com') || host.contains('byteoversea.com') || host.contains('ibytedtos.com');
    if (isTiktok) {
      cleanHeaders.remove('Cookie');
      cleanHeaders.remove('cookie');
      cleanHeaders.remove('Referer');
      cleanHeaders.remove('Origin');
      cleanHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
      cleanHeaders['Accept'] = '*/*';
    } else {
      final isCdn = !host.contains('missav') && !host.contains('jable') && !host.contains('fs1.app') && !host.contains('supjav');
      if (isCdn) {
        cleanHeaders.remove('Cookie');
        cleanHeaders.remove('cookie');
        cleanHeaders['Accept'] = '*/*';
      }
    }

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        Uint8List? rawBytes;
        final reqHeaders = attempt > 1 && !isTiktok
            ? (Map<String, String>.from(cleanHeaders)..remove('Referer')..remove('Origin'))
            : cleanHeaders;

        // 1. First try direct native Dio socket (fastest)
        try {
          final response = await dio.get<List<int>>(
            url,
            options: Options(
              headers: reqHeaders,
              responseType: ResponseType.bytes,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
            ),
          );
          if (response.statusCode == 200 && response.data != null) {
            rawBytes = Uint8List.fromList(response.data!);
          }
        } catch (_) {}

        // 2. If Dio fails, use persistent warm Chromium tunnel
        if (rawBytes == null || rawBytes.isEmpty) {
          final tunnelBytes = await PersistentChromiumTunnel.fetchBytes(
            url,
            siteName: siteName,
            headers: cleanHeaders,
          );
          if (tunnelBytes != null && tunnelBytes.isNotEmpty) {
            rawBytes = tunnelBytes;
          }
        }

        if (rawBytes == null || rawBytes.isEmpty) {
          throw Exception("Failed to fetch segment data for $url");
        }
        
        final rawBytesCount = rawBytes.length;
        Uint8List segmentData = rawBytes;
        
        // 3. If SupJav, strip fake PNG header if present
        if (siteName.toLowerCase() == 'supjav') {
          final stripped = Decryptor.stripSupJavHeader(segmentData);
          if (stripped.isNotEmpty) {
            segmentData = stripped;
          }
        }
        
        // 4. If AES key is present, decrypt the segment on background isolate
        if (decryptKey != null && decryptIv != null) {
          segmentData = await Decryptor.decryptSegmentAsync(segmentData, decryptKey, decryptIv);
        }
        
        // Write the decrypted segment to disk atomically via .part file
        await partFile.writeAsBytes(segmentData, flush: false);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        await partFile.rename(savePath);
        return rawBytesCount;
      } catch (e) {
        if (await partFile.exists()) {
          try {
            await partFile.delete();
          } catch (_) {}
        }
        if (attempt >= maxRetries) {
          return -1;
        }
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
    return -1;
  }
}
