import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/services/pornhub/pornhub_api_service.dart';

void main() {
  group('PornhubApiService Tests', () {
    test('isVideoUrlExpired correctly detects expired and valid tokens', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Expired Edgecast token (validto in past)
      final expiredEdgecast =
          'https://ev-h.phncdn.com/hls/test.m3u8?validfrom=10000&validto=${nowSec - 100}&hash=abc';
      expect(PornhubApiService.isVideoUrlExpired(expiredEdgecast), isTrue);

      // Expiring Edgecast token (validto within 5 minutes)
      final expiringEdgecast =
          'https://ev-h.phncdn.com/hls/test.m3u8?validfrom=10000&validto=${nowSec + 120}&hash=abc';
      expect(PornhubApiService.isVideoUrlExpired(expiringEdgecast), isTrue);

      // Valid Edgecast token (validto 2 hours from now)
      final validEdgecast =
          'https://ev-h.phncdn.com/hls/test.m3u8?validfrom=10000&validto=${nowSec + 7200}&hash=abc';
      expect(PornhubApiService.isVideoUrlExpired(validEdgecast), isFalse);

      // Expired Cloudflare token (e in past)
      final expiredCloudflare =
          'https://hv-h.phncdn.com/hls/test.m3u8?h=xyz&e=${nowSec - 60}&f=1';
      expect(PornhubApiService.isVideoUrlExpired(expiredCloudflare), isTrue);

      // Valid Cloudflare token (e 2 hours from now)
      final validCloudflare =
          'https://hv-h.phncdn.com/hls/test.m3u8?h=xyz&e=${nowSec + 7200}&f=1';
      expect(PornhubApiService.isVideoUrlExpired(validCloudflare), isFalse);

      // Non-token URL
      final simpleUrl = 'https://example.com/video.mp4';
      expect(PornhubApiService.isVideoUrlExpired(simpleUrl), isFalse);
    });
  });
}
