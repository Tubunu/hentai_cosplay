import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/resource_site_item.dart';
import 'package:hentai_cosplay_downloader/services/random_discovery_service.dart';
import 'package:hentai_cosplay_downloader/services/xhamster/xhamster_api_service.dart';
import 'package:hentai_cosplay_downloader/services/xnxx/xnxx_api_service.dart';
import 'package:hentai_cosplay_downloader/providers/xhamster_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/xnxx_browse_provider.dart';
import 'package:hentai_cosplay_downloader/models/video_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResourceSiteRegistry Integration Tests', () {
    test('defaultOrder contains xhamster and xnxx', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('xhamster'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('xnxx'), isTrue);
    });

    test('allSites contains xhamster and xnxx with proper metadata', () {
      final xh = ResourceSiteRegistry.allSites['xhamster'];
      expect(xh, isNotNull);
      expect(xh!.label, equals('xHamster'));
      expect(xh.key, equals('xhamster'));

      final xn = ResourceSiteRegistry.allSites['xnxx'];
      expect(xn, isNotNull);
      expect(xn!.label, equals('XNXX'));
      expect(xn.key, equals('xnxx'));
    });

    test('getOrderedSites handles ordering and hiding correctly', () {
      final all = ResourceSiteRegistry.getOrderedSites(null);
      expect(all.any((s) => s.key == 'xhamster'), isTrue);
      expect(all.any((s) => s.key == 'xnxx'), isTrue);

      final hidden = ResourceSiteRegistry.getOrderedSites(null, hiddenKeys: ['xhamster', 'xnxx']);
      expect(hidden.any((s) => s.key == 'xhamster'), isFalse);
      expect(hidden.any((s) => s.key == 'xnxx'), isFalse);
    });
  });

  group('VideoSiteType & Random Enum Tests', () {
    test('VideoSiteType enum contains xhamster and xnxx', () {
      expect(VideoSiteType.values.any((e) => e.name == 'xhamster'), isTrue);
      expect(VideoSiteType.values.any((e) => e.name == 'xnxx'), isTrue);
      expect(VideoSiteType.xhamster.label, equals('xHamster'));
      expect(VideoSiteType.xnxx.label, equals('XNXX'));
    });
  });

  group('XhamsterApiService URL Builder Tests', () {
    test('buildUrl trending', () {
      expect(
        XhamsterApiService.buildUrl(page: 1, category: XhamsterCategory.trending),
        equals('https://xhamster.com/best'),
      );
      expect(
        XhamsterApiService.buildUrl(page: 2, category: XhamsterCategory.trending),
        equals('https://xhamster.com/best/2'),
      );
    });

    test('buildUrl newest and cosplay', () {
      expect(
        XhamsterApiService.buildUrl(page: 1, category: XhamsterCategory.newest),
        equals('https://xhamster.com/newest'),
      );
      expect(
        XhamsterApiService.buildUrl(page: 1, category: XhamsterCategory.cosplay),
        equals('https://xhamster.com/categories/cosplay'),
      );
      expect(
        XhamsterApiService.buildUrl(page: 3, category: XhamsterCategory.cosplay),
        equals('https://xhamster.com/categories/cosplay/3'),
      );
    });

    test('buildUrl search', () {
      expect(
        XhamsterApiService.buildUrl(page: 1, keyword: 'cosplay'),
        equals('https://xhamster.com/search/cosplay'),
      );
      expect(
        XhamsterApiService.buildUrl(page: 2, keyword: 'cosplay'),
        equals('https://xhamster.com/search/cosplay?page=2'),
      );
    });
  });

  group('XnxxApiService URL Builder Tests', () {
    test('buildUrl hits', () {
      expect(
        XnxxApiService.buildUrl(page: 1, category: XnxxCategory.hits),
        equals('https://www.xnxx.com/hits'),
      );
      expect(
        XnxxApiService.buildUrl(page: 2, category: XnxxCategory.hits),
        equals('https://www.xnxx.com/hits/1'),
      );
    });

    test('buildUrl best with month', () {
      expect(
        XnxxApiService.buildUrl(page: 1, category: XnxxCategory.best, bestMonth: '2026-07'),
        equals('https://www.xnxx.com/best/2026-07'),
      );
      expect(
        XnxxApiService.buildUrl(page: 2, category: XnxxCategory.best, bestMonth: '2026-07'),
        equals('https://www.xnxx.com/best/2026-07/1'),
      );
    });

    test('buildUrl search', () {
      expect(
        XnxxApiService.buildUrl(page: 1, keyword: 'cosplay'),
        equals('https://www.xnxx.com/search/cosplay'),
      );
      expect(
        XnxxApiService.buildUrl(page: 2, keyword: 'cosplay'),
        equals('https://www.xnxx.com/search/cosplay/1'),
      );
    });
  });

  group('XhamsterBrowseProvider State Tests', () {
    test('selection mode and toggle', () {
      final provider = XhamsterBrowseProvider(autoLoad: false);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedCount, equals(0));

      final testItem = VideoItem(
        title: 'Test Video',
        slug: 'test-123',
        detailUrl: 'https://xhamster.com/videos/test-123',
        coverUrl: 'https://thumb.com/1.jpg',
        duration: '10:00',
        views: '10k',
        date: '',
        author: '',
      );

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.isSelected(testItem), isTrue);
      expect(provider.selectedCount, equals(1));

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.isSelected(testItem), isFalse);
      expect(provider.selectedCount, equals(0));
    });
  });

  group('XnxxBrowseProvider State Tests', () {
    test('category and month switching', () {
      final provider = XnxxBrowseProvider(autoLoad: false);
      expect(provider.category, equals(XnxxCategory.hits));

      provider.selectBestMonth('2026-05');
      expect(provider.category, equals(XnxxCategory.best));
      expect(provider.bestMonth, equals('2026-05'));
    });
  });

  group('XNXX Parser Authentic Title Tests', () {
    test('extracts genuine title from .thumb-under p a instead of fallback placeholder', () {
      const sampleHtml = '''
      <div class="thumb-block with-uploader" id="video_1dgzb774">
        <div class="thumb-inside">
          <div class="thumb">
            <a href="/video-1dgzb774/_-_">
              <img src="https://assets.xnxx.com/blank.gif" data-src="https://thumb.xnxx.com/1.jpg" />
            </a>
          </div>
        </div>
        <div class="thumb-under">
          <p>
            <a href="/video-1dgzb774/_-_" title="麻豆傳媒映画 - 換上萬聖裝扮挑逗你的性慾">
              麻豆傳媒映画 - 換上萬聖裝扮挑逗你的性慾
            </a>
          </p>
          <p class="metadata">
            <span class="right">1.6M 100%</span>
            16min - 1080p
          </p>
        </div>
      </div>
      ''';

      final pageData = XnxxApiService.parseListPageHtmlForTest(sampleHtml, 1);
      expect(pageData.items.length, equals(1));
      expect(pageData.items.first.title, equals('麻豆傳媒映画 - 換上萬聖裝扮挑逗你的性慾'));
      expect(pageData.items.first.detailUrl, equals('https://www.xnxx.com/video-1dgzb774/_-_'));
      expect(pageData.items.first.coverUrl, equals('https://thumb.xnxx.com/1.jpg'));
    });
  });

  group('xHamster Parser Multi-Category Thumbnails Tests', () {
    test('extracts thumbnails from category trendingVideoListProps in window.initials', () {
      const sampleHtml = '''
      <html><body>
      <script>
      window.initials = {
        "pagesCategoryComponent": {
          "trendingVideoListProps": {
            "videoThumbProps": [
              {
                "id": 30053644,
                "title": "Marin Kitagawa - Full Cosplay Day Compilation",
                "pageURL": "https://xhamster.com/videos/marin-kitagawa-xh1Jxkm",
                "thumbURL": "https://ic-vt-nss.xhcdn.com/1.webp",
                "duration": 976,
                "views": 482000
              }
            ]
          },
          "paginationProps": {
            "lastPageNumber": 25
          }
        }
      };
      </script>
      </body></html>
      ''';

      final pageData = XhamsterApiService.parseListPageHtmlForTest(sampleHtml, 1);
      expect(pageData.items.length, equals(1));
      expect(pageData.items.first.title, equals('Marin Kitagawa - Full Cosplay Day Compilation'));
      expect(pageData.items.first.coverUrl, equals('https://ic-vt-nss.xhcdn.com/1.webp'));
      expect(pageData.items.first.duration, equals('16:16'));
      expect(pageData.totalPages, equals(25));
    });
  });
}
