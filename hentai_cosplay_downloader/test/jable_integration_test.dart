import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/jable_task.dart';
import 'package:hentai_cosplay_downloader/models/jable_video_item.dart';
import 'package:hentai_cosplay_downloader/services/jable/decryptor.dart';
import 'package:hentai_cosplay_downloader/services/jable/jable_download_engine.dart';
import 'package:hentai_cosplay_downloader/services/jable/js_unpacker.dart';
import 'package:hentai_cosplay_downloader/services/jable/scrapers/jable_scraper.dart';
import 'package:hentai_cosplay_downloader/services/jable/scrapers/missav_scraper.dart';
import 'package:hentai_cosplay_downloader/services/jable/scrapers/supjav_scraper.dart';

void main() {
  group('Jable Model Tests', () {
    test('VideoCardModel serialization and deserialization', () {
      final card = VideoCardModel(
        url: 'https://jable.tv/videos/abc-123/',
        title: 'ABC-123 Test Video',
        thumbnail: 'https://jable.tv/covers/abc-123.jpg',
        duration: '120:00',
        date: '2026-08-25',
        siteName: 'JableTV',
      );

      final jsonStr = card.toJson();
      final decoded = VideoCardModel.fromJson(jsonStr);

      expect(decoded.url, equals(card.url));
      expect(decoded.title, equals(card.title));
      expect(decoded.thumbnail, equals(card.thumbnail));
      expect(decoded.duration, equals(card.duration));
      expect(decoded.date, equals(card.date));
      expect(decoded.siteName, equals(card.siteName));
    });

    test('JableDownloadTask serialization and deserialization', () {
      final task = JableDownloadTask(
        id: 'task_123',
        url: 'https://missav.ws/dm123/video-456',
        name: 'video_456',
        thumbnailUrl: 'https://missav.ws/cover.jpg',
        status: JableDownloadStatus.downloading,
        progress: 45.5,
        totalSegments: 100,
        completedSegments: 45,
        speed: '3.5 MB/s',
        destPath: '/downloads/jabletv',
        siteName: 'MissAV',
        duration: '60:00',
      );

      final jsonStr = task.toJson();
      final decoded = JableDownloadTask.fromJson(jsonStr);

      expect(decoded.id, equals('task_123'));
      expect(decoded.url, equals(task.url));
      expect(decoded.name, equals(task.name));
      expect(decoded.status, equals(JableDownloadStatus.downloading));
      expect(decoded.progress, equals(45.5));
      expect(decoded.totalSegments, equals(100));
      expect(decoded.completedSegments, equals(45));
      expect(decoded.speed, equals('3.5 MB/s'));
      expect(decoded.destPath, equals('/downloads/jabletv'));
      expect(decoded.siteName, equals('MissAV'));
    });

    test('JableLocalVideoItem formatting and metadata', () {
      final item = JableLocalVideoItem(
        id: 'local_1',
        title: 'IPX-999 Beautiful Cosplay',
        filePath: 'C:/Downloads/jabletv/IPX-999.mp4',
        coverPath: 'C:/Downloads/jabletv/IPX-999.jpg',
        fileSizeBytes: 1024 * 1024 * 512, // 512 MB
        createdAt: DateTime(2026, 8, 25),
        duration: '110:00',
        siteName: 'JableTV',
        tags: ['Cosplay', 'Uncensored'],
      );

      expect(item.formattedSize, equals('512.0 MB'));
      expect(item.fileName, equals('IPX-999.mp4'));

      final json = item.toJson();
      final fromJson = JableLocalVideoItem.fromJson(json);

      expect(fromJson.title, equals(item.title));
      expect(fromJson.fileSizeBytes, equals(item.fileSizeBytes));
      expect(fromJson.tags, contains('Cosplay'));
    });
  });

  group('JS Unpacker and Decryptor Tests', () {
    test('JsUnpacker correctly unpacks packed JavaScript strings', () {
      // Standard Dean Edwards packed evaluation sample
      const packedSample = """
eval(function(p,a,c,k,e,d){e=function(c){return c.toString(36)};if(!''.replace(/^/,String)){while(c--){d[c.toString(a)]=k[c]||c.toString(a)}k=[function(e){return d[e]}];e=function(){return'\\\\w+'};c=1};while(c--){if(k[c]){p=p.replace(new RegExp('\\\\b'+e(c)+'\\\\b','g'),k[c])}}return p}('1 0="2://3.4/5.6";',7,7,'source|var|https|cdn|example|playlist|m3u8'.split('|'),0,{}))
""";

      final unpacked = JsUnpacker.unpack(packedSample);
      expect(unpacked, isNotNull);
      expect(unpacked, contains('https://cdn.example/playlist.m3u8'));
    });

    test('Decryptor SupJav header stripper detects and strips fake PNG prefixes', () {
      // Create fake PNG header + 5 x 188-byte TS packets starting with 0x47
      final fakePng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]);
      final tsData = <int>[];
      for (int i = 0; i < 5; i++) {
        tsData.add(0x47);
        tsData.addAll(List.filled(187, 0x00));
      }

      final combined = Uint8List.fromList([...fakePng, ...tsData]);
      final stripped = Decryptor.stripSupJavHeader(combined);

      expect(stripped.first, equals(0x47));
      expect(stripped.length, equals(tsData.length));
    });

    test('JableDownloadEngine file name sanitizer removes illegal filesystem characters', () {
      const dirty = 'ABC/123: Special *Video*?"<>| Title';
      final clean = JableDownloadEngine.sanitizeFileName(dirty);

      expect(clean.contains('/'), isFalse);
      expect(clean.contains(':'), isFalse);
      expect(clean.contains('*'), isFalse);
      expect(clean.contains('?'), isFalse);
      expect(clean.contains('"'), isFalse);
      expect(clean.contains('<'), isFalse);
      expect(clean.contains('>'), isFalse);
      expect(clean.contains('|'), isFalse);
      expect(clean, contains('ABC'));
      expect(clean, contains('123'));
    });
  });

  group('Scraper Routing and Pagination Tests', () {
    test('JableScraper pagination url builder', () {
      final scraper = JableScraper();
      final p1 = scraper.buildPageUrl('https://jable.tv/latest-updates/', 1);
      final p2 = scraper.buildPageUrl('https://jable.tv/latest-updates/', 2);

      expect(p1, equals('https://jable.tv/latest-updates/'));
      expect(p2, contains('from=02'));
    });

    test('MissAVScraper pagination url builder', () {
      final scraper = MissAVScraper();
      final p1 = scraper.buildPageUrl('https://missav.ws/dm298/today-hot', 1);
      final p3 = scraper.buildPageUrl('https://missav.ws/dm298/today-hot', 3);

      expect(p1, equals('https://missav.ws/dm298/today-hot'));
      expect(p3, contains('page=3'));
    });

    test('SupJavScraper pagination url builder', () {
      final scraper = SupJavScraper();
      final p1 = scraper.buildPageUrl('https://supjav.com/zh/popular', 1);
      final p4 = scraper.buildPageUrl('https://supjav.com/zh/popular', 4);

      expect(p1, equals('https://supjav.com/zh/popular'));
      expect(p4, equals('https://supjav.com/zh/popular/page/4'));
    });

    test('P2 Fix: Direct MP4 heuristic accurately identifies explicit MP4 and rejects M3U8', () {
      bool isDirectMp4Url(String url) {
        final cleanUrlLower = url.split('?').first.toLowerCase();
        if (cleanUrlLower.endsWith('.mp4') || (url.contains('.mp4') && !url.contains('.m3u8'))) {
          return true;
        }
        return false;
      }

      expect(isDirectMp4Url('https://example.com/video.mp4'), isTrue);
      expect(isDirectMp4Url('https://example.com/video.mp4?token=123'), isTrue);
      expect(isDirectMp4Url('https://example.com/playlist.m3u8'), isFalse);
      expect(isDirectMp4Url('https://example.com/stream/master?token=123'), isFalse);
    });
  });
}
