import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/ui/site_registry.dart';
import 'package:hentai_cosplay_downloader/models/video_item.dart';
import 'package:hentai_cosplay_downloader/providers/njav_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/vjav_browse_provider.dart';
import 'package:hentai_cosplay_downloader/services/njav/njav_api_service.dart';
import 'package:hentai_cosplay_downloader/services/random_discovery_service.dart';
import 'package:hentai_cosplay_downloader/services/vjav/vjav_api_service.dart';

void main() {
  group('ResourceSiteRegistry NJAV & VJAV Integration Tests', () {
    test('defaultOrder contains njav and vjav', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('njav'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('vjav'), isTrue);
    });

    test('allSites contains njav and vjav with valid metadata and builders', () {
      final njavSite = ResourceSiteRegistry.allSites['njav'];
      expect(njavSite, isNotNull);
      expect(njavSite!.key, equals('njav'));
      expect(njavSite.label, equals('NJAV'));
      expect(njavSite.color, equals(const Color(0xFFFE628E)));

      final vjavSite = ResourceSiteRegistry.allSites['vjav'];
      expect(vjavSite, isNotNull);
      expect(vjavSite!.key, equals('vjav'));
      expect(vjavSite.label, equals('VJAV'));
      expect(vjavSite.color, equals(const Color(0xFFFF9900)));
    });

    test('getOrderedSites includes njav and vjav', () {
      final ordered = ResourceSiteRegistry.getOrderedSites(null);
      final keys = ordered.map((e) => e.key).toList();
      expect(keys.contains('njav'), isTrue);
      expect(keys.contains('vjav'), isTrue);
    });
  });

  group('VideoSiteType Enum Tests', () {
    test('VideoSiteType enum contains njav and vjav', () {
      expect(VideoSiteType.values.any((e) => e.name == 'njav'), isTrue);
      expect(VideoSiteType.values.any((e) => e.name == 'vjav'), isTrue);
      expect(VideoSiteType.njav.label, equals('NJAV'));
      expect(VideoSiteType.vjav.label, equals('VJAV'));
    });
  });

  group('NjavApiService URL Builder & Parser Tests', () {
    test('buildUrl catalog', () {
      expect(
        NjavApiService.buildUrl(page: 1, category: NjavCategory.recentUpdate),
        equals('https://www.njav.com/zh/recent-update/'),
      );
      expect(
        NjavApiService.buildUrl(page: 2, category: NjavCategory.recentUpdate),
        equals('https://www.njav.com/zh/recent-update/?page=2'),
      );
      expect(
        NjavApiService.buildUrl(page: 1, category: NjavCategory.censored),
        equals('https://www.njav.com/zh/censored/'),
      );
    });

    test('buildUrl search', () {
      expect(
        NjavApiService.buildUrl(page: 1, keyword: 'aika'),
        equals('https://www.njav.com/zh/search?keyword=aika'),
      );
      expect(
        NjavApiService.buildUrl(page: 3, keyword: 'aika cosplay'),
        equals('https://www.njav.com/zh/search?keyword=aika%20cosplay&page=3'),
      );
    });

    test('parseListPageHtml extracts items, duration, and fallback cover', () {
      const sampleHtml = '''
      <div class="row box-item-list">
        <div class="col-6 col-sm-4 col-lg-3">
          <div class="box-item">
            <div class="thumb" v-scope="Preview('https://static.javcdn.vip/preview/hrsm-158/preview.mp4')">
              <a href="xvideos/hrsm-158" rel="nofollow">
                <img class="lazyload" data-src="https://static.javcdn.vip/resize/hrsm-158/thumb_h.webp" src="data:image/png;base64,..." />
              </a>
              <div class="duration">02:15:46</div>
            </div>
            <div class="detail">
              <a href="xvideos/hrsm-158">HRSM-158 激かわ女子大生</a>
            </div>
          </div>
        </div>
      </div>
      <ul class="pagination">
        <li><a href="?page=1">1</a></li>
        <li><a href="?page=2">2</a></li>
        <li><a href="?page=5">5</a></li>
      </ul>
      ''';

      final pageData = NjavApiService.parseListPageHtmlForTest(sampleHtml, 1);
      expect(pageData.items.length, equals(1));
      final item = pageData.items.first;
      expect(item.slug, equals('hrsm-158'));
      expect(item.title, equals('HRSM-158 激かわ女子大生'));
      expect(item.coverUrl, equals('https://static.javcdn.vip/resize/hrsm-158/thumb_h.webp'));
      expect(item.duration, equals('02:15:46'));
      expect(item.rawData['preview_video'], equals('https://static.javcdn.vip/preview/hrsm-158/preview.mp4'));
      expect(pageData.totalPages, equals(5));
    });
  });

  group('VjavApiService URL Builder, Parser & Decipher Tests', () {
    test('buildUrl catalog', () {
      expect(
        VjavApiService.buildUrl(page: 1, category: VjavCategory.latest),
        equals('https://vjav.com/api/json/videos2/86400/str/latest-updates/60/..1.all...json'),
      );
      expect(
        VjavApiService.buildUrl(page: 2, category: VjavCategory.popular),
        equals('https://vjav.com/api/json/videos2/86400/str/most-popular/60/..2.all...json'),
      );
    });

    test('buildUrl search', () {
      expect(
        VjavApiService.buildUrl(page: 1, keyword: 'school'),
        equals('https://vjav.com/api/videos2.php?params=86400/str/relevance/60/search..1.all..&s=school'),
      );
    });

    test('parsePageData parses API json objects correctly', () {
      final sampleJson = {
        'total_count': 120,
        'pages': 2,
        'videos': [
          {
            'video_id': '990059',
            'title': 'Yuki Chitose FJIN-136',
            'dir': 'yuki-chitose-fjin-136',
            'duration': '08:00',
            'video_viewed': 1500,
            'rating': '92',
            'scr': 'https://tn.vjav.com/contents/videos_screenshots/990000/990059/240x180/1.jpg',
            'models': 'Yuki Chitose',
            'categories': 'Asian,Censored',
          }
        ]
      };

      final pageData = VjavApiService.parsePageData(sampleJson, 1);
      expect(pageData.items.length, equals(1));
      final item = pageData.items.first;
      expect(item.slug, equals('990059'));
      expect(item.title, equals('Yuki Chitose FJIN-136'));
      expect(item.duration, equals('08:00'));
      expect(item.views, equals('1.5K'));
      expect(item.tags.contains('Yuki Chitose'), isTrue);
      expect(item.tags.contains('Asian'), isTrue);
      expect(pageData.totalPages, equals(2));
      expect(pageData.totalCount, equals(120));
    });

    test('decodeStreamUrl cleanly decodes custom Cyrillic cipher into valid stream URL', () {
      const encrypted =
          "L2dldF9maWxlLz\u041cvYmVlOD\u0410yZDll\u041cmUwNTIyNWI1Yzc5OTFkND\u0415xYjIx\u041cD\u041c5ZGZi\u041cjRm\u041czljLzk5\u041cD\u0410w\u041c\u042185OT\u0410wNTkvOTkw\u041cDU5X2hxLm1wN\u04218,ZD00OD\u0410mYnI9\u041cT\u04105JnRpPT\u04153ODg0ODYwNzY~";
      final decoded = VjavApiService.decodeStreamUrl(encrypted);
      expect(decoded.startsWith('/get_file/'), isTrue);
      expect(decoded.contains('.mp4'), isTrue);
      expect(decoded, equals('/get_file/3/bee802d9e2e05225b5c7991d411b21039dfb24f39c/990000/990059/990059_hq.mp4/?d=480&br=109&ti=1788486076'));
    });
  });

  group('Browse Provider States Tests', () {
    test('NjavBrowseProvider state and selection', () {
      final provider = NjavBrowseProvider(autoLoad: false);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.currentCategory, equals(NjavCategory.recentUpdate));

      final testItem = VideoItem(
        title: 'Test NJAV Video',
        slug: 'hrsm-158',
        detailUrl: 'https://www.njav.com/zh/xvideos/hrsm-158',
        coverUrl: 'https://static.javcdn.vip/resize/hrsm-158/thumb_h.webp',
        duration: '02:00:00',
        views: '',
        date: '',
        author: 'NJAV',
      );

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.isSelected(testItem), isTrue);
      expect(provider.selectedCount, equals(1));

      provider.clearSelection();
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedCount, equals(0));
    });

    test('VjavBrowseProvider state and selection', () {
      final provider = VjavBrowseProvider(autoLoad: false);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.currentCategory, equals(VjavCategory.latest));

      final testItem = VideoItem(
        title: 'Test VJAV Video',
        slug: '990059',
        detailUrl: 'https://vjav.com/videos/990059/dir/',
        coverUrl: 'https://tn.vjav.com/1.jpg',
        duration: '10:00',
        views: '10K',
        date: '',
        author: 'VJAV',
      );

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.isSelected(testItem), isTrue);
      expect(provider.selectedCount, equals(1));

      provider.clearSelection();
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedCount, equals(0));
    });
  });
}
