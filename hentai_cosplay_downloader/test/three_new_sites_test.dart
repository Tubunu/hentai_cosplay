import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/ui/site_registry.dart';
import 'package:hentai_cosplay_downloader/models/video_item.dart';
import 'package:hentai_cosplay_downloader/providers/av123_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/javguru_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/javmost_browse_provider.dart';
import 'package:hentai_cosplay_downloader/services/av123/av123_api_service.dart';
import 'package:hentai_cosplay_downloader/services/javguru/javguru_api_service.dart';
import 'package:hentai_cosplay_downloader/services/javmost/javmost_api_service.dart';
import 'package:hentai_cosplay_downloader/services/random_discovery_service.dart';

void main() {
  group('ResourceSiteRegistry JavGuru, 123AV & JavMost Integration Tests', () {
    test('defaultOrder contains javguru, av123, and javmost', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('javguru'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('av123'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('javmost'), isTrue);
    });

    test('allSites contains javguru, av123, and javmost with valid metadata and builders', () {
      final javguruSite = ResourceSiteRegistry.allSites['javguru'];
      expect(javguruSite, isNotNull);
      expect(javguruSite!.key, equals('javguru'));
      expect(javguruSite.label, equals('JavGuru'));
      expect(javguruSite.color, equals(const Color(0xFF00ADB5)));

      final av123Site = ResourceSiteRegistry.allSites['av123'];
      expect(av123Site, isNotNull);
      expect(av123Site!.key, equals('av123'));
      expect(av123Site.label, equals('123AV'));
      expect(av123Site.color, equals(const Color(0xFFE50914)));

      final javmostSite = ResourceSiteRegistry.allSites['javmost'];
      expect(javmostSite, isNotNull);
      expect(javmostSite!.key, equals('javmost'));
      expect(javmostSite.label, equals('JavMost'));
      expect(javmostSite.color, equals(const Color(0xFFA80000)));
    });

    test('getOrderedSites includes javguru, av123, and javmost', () {
      final ordered = ResourceSiteRegistry.getOrderedSites(null);
      final keys = ordered.map((e) => e.key).toList();
      expect(keys.contains('javguru'), isTrue);
      expect(keys.contains('av123'), isTrue);
      expect(keys.contains('javmost'), isTrue);
    });
  });

  group('VideoSiteType Enum Tests', () {
    test('VideoSiteType enum contains javguru, av123, and javmost', () {
      expect(VideoSiteType.values.any((e) => e.name == 'javguru'), isTrue);
      expect(VideoSiteType.values.any((e) => e.name == 'av123'), isTrue);
      expect(VideoSiteType.values.any((e) => e.name == 'javmost'), isTrue);
      expect(VideoSiteType.javguru.label, equals('JavGuru'));
      expect(VideoSiteType.av123.label, equals('123AV'));
      expect(VideoSiteType.javmost.label, equals('JavMost'));
    });
  });

  group('JavguruApiService Tests', () {
    test('buildUrl catalog', () {
      expect(
        JavguruApiService.buildUrl(page: 1, category: JavguruCategory.all),
        equals('https://jav.guru/'),
      );
      expect(
        JavguruApiService.buildUrl(page: 2, category: JavguruCategory.all),
        equals('https://jav.guru/page/2/'),
      );
      expect(
        JavguruApiService.buildUrl(page: 1, category: JavguruCategory.decensored),
        equals('https://jav.guru/category/decensored/'),
      );
      expect(
        JavguruApiService.buildUrl(page: 3, category: JavguruCategory.decensored),
        equals('https://jav.guru/category/decensored/page/3/'),
      );
    });

    test('buildUrl search', () {
      expect(
        JavguruApiService.buildUrl(page: 1, keyword: 'cosplay'),
        equals('https://jav.guru/?s=cosplay'),
      );
      expect(
        JavguruApiService.buildUrl(page: 4, keyword: 'snos 313'),
        equals('https://jav.guru/page/4/?s=snos%20313'),
      );
    });

    test('parseHtml extracts card items', () {
      const sampleHtml = '''
      <div class="inside-article">
        <div class="imgg">
          <a href="https://jav.guru/1048112/snos-313-title/">
            <img src="https://cdn.javmiku.com/uploads/snos313.jpg" alt="SNOS-313 Sample Title" />
          </a>
        </div>
        <h2 class="entry-title">
          <a href="https://jav.guru/1048112/snos-313-title/">SNOS-313 Sample Title</a>
        </h2>
      </div>
      <div class="nav-links">
        <a class="page-numbers" href="/page/1/">1</a>
        <a class="page-numbers" href="/page/2/">2</a>
        <a class="page-numbers" href="/page/5/">5</a>
      </div>
      ''';

      final pageData = JavguruApiService.parseHtml(sampleHtml, currentPage: 1);
      expect(pageData.items.length, equals(1));
      expect(pageData.items.first.title, equals('SNOS-313 Sample Title'));
      expect(pageData.items.first.detailUrl, equals('https://jav.guru/1048112/snos-313-title/'));
      expect(pageData.items.first.coverUrl, equals('https://cdn.javmiku.com/uploads/snos313.jpg'));
      expect(pageData.totalPages, equals(5));
    });
  });

  group('Av123ApiService Tests', () {
    test('buildUrl catalog', () {
      expect(
        Av123ApiService.buildUrl(page: 1, category: Av123Category.newest),
        equals('https://123av.com/cn/new'),
      );
      expect(
        Av123ApiService.buildUrl(page: 2, category: Av123Category.newest),
        equals('https://123av.com/cn/new?page=2'),
      );
      expect(
        Av123ApiService.buildUrl(page: 3, category: Av123Category.today),
        equals('https://123av.com/cn/all?sort=today&page=3'),
      );
    });

    test('buildUrl search', () {
      expect(
        Av123ApiService.buildUrl(page: 1, keyword: 'cosplay'),
        equals('https://123av.com/cn/search?keyword=cosplay&page=1'),
      );
      expect(
        Av123ApiService.buildUrl(page: 2, keyword: 'roe 545'),
        equals('https://123av.com/cn/search?keyword=roe%20545&page=2'),
      );
    });

    test('parseHtml extracts card items and duration', () {
      const sampleHtml = '''
      <div class="card">
        <a href="/cn/v/roe-545">
          <img data-src="https://icdn.123av.me/img/roe-545.jpg" />
        </a>
        <div class="card-title">ROE-545 Sample 123AV Video</div>
        <span class="duration">01:58:30</span>
      </div>
      <div class="pagination">
        <a href="?page=1">1</a>
        <a href="?page=2">2</a>
        <a href="?page=8">8</a>
      </div>
      ''';

      final pageData = Av123ApiService.parseHtml(sampleHtml, currentPage: 1);
      expect(pageData.items.length, equals(1));
      expect(pageData.items.first.title, equals('ROE-545 Sample 123AV Video'));
      expect(pageData.items.first.detailUrl, equals('https://123av.com/cn/v/roe-545'));
      expect(pageData.items.first.coverUrl, equals('https://icdn.123av.me/img/roe-545.jpg'));
      expect(pageData.items.first.duration, equals('01:58:30'));
      expect(pageData.totalPages, equals(8));
    });

    test('parseHtml sanitizes 0:00 duration to empty', () {
      const sampleHtml = '''
      <div class="card">
        <a href="/cn/v/abc-123">
          <img data-src="https://icdn.123av.me/img/abc-123.jpg" />
        </a>
        <div class="card-title">ABC-123 Zero Duration Video</div>
        <span class="card__dur">0:00</span>
      </div>
      ''';

      final pageData = Av123ApiService.parseHtml(sampleHtml, currentPage: 1);
      expect(pageData.items.length, equals(1));
      expect(pageData.items.first.duration, equals(''));
    });
  });

  group('JavmostApiService Tests', () {
    test('buildUrl catalog', () {
      expect(
        JavmostApiService.buildUrl(page: 1, category: JavmostCategory.all),
        equals('https://www.javmost.ws/category/all/'),
      );
      expect(
        JavmostApiService.buildUrl(page: 2, category: JavmostCategory.all),
        equals('https://www.javmost.ws/category/all/page/2/'),
      );
      expect(
        JavmostApiService.buildUrl(page: 1, category: JavmostCategory.censor),
        equals('https://www.javmost.ws/category/censor/'),
      );
    });

    test('buildUrl search', () {
      expect(
        JavmostApiService.buildUrl(page: 1, keyword: 'cosplay'),
        equals('https://www.javmost.ws/search/cosplay/'),
      );
      expect(
        JavmostApiService.buildUrl(page: 3, keyword: 'snos'),
        equals('https://www.javmost.ws/search/snos/page/3/'),
      );
    });

    test('parseHtml extracts card items', () {
      const sampleHtml = '''
      <div class="card">
        <a href="https://www.javmost.ws/SNOS-363/">
          <img data-src="https://img2.javmost.ws/SNOS-363.jpg" />
        </a>
        <div class="card-body">
          <h4 class="title">SNOS-363 Beautiful JavMost</h4>
        </div>
      </div>
      <div class="pagination">
        <a href="/category/all/page/1/">1</a>
        <a href="/category/all/page/2/">2</a>
        <a href="/category/all/page/6/">6</a>
      </div>
      ''';

      final pageData = JavmostApiService.parseHtml(sampleHtml, currentPage: 1);
      expect(pageData.items.length, equals(1));
      expect(pageData.items.first.title, equals('SNOS-363 Beautiful JavMost'));
      expect(pageData.items.first.detailUrl, equals('https://www.javmost.ws/SNOS-363/'));
      expect(pageData.items.first.coverUrl, equals('https://img2.javmost.ws/SNOS-363.jpg'));
      expect(pageData.totalPages, equals(6));
    });
  });

  group('BrowseProvider Selection & State Tests', () {
    test('JavguruBrowseProvider selection', () {
      final provider = JavguruBrowseProvider(autoLoad: false);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedCount, equals(0));

      final testItem = VideoItem(
        title: 'Test',
        detailUrl: 'https://jav.guru/123/',
        slug: 'https://jav.guru/123/',
        date: '',
        author: '',
      );

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.selectedCount, equals(1));
      expect(provider.isSelected(testItem), isTrue);

      provider.clearSelection();
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedCount, equals(0));
    });

    test('Av123BrowseProvider selection', () {
      final provider = Av123BrowseProvider(autoLoad: false);
      final testItem = VideoItem(
        title: 'Test 123',
        detailUrl: 'https://123av.com/cn/v/abc',
        slug: 'https://123av.com/cn/v/abc',
        date: '',
        author: '',
      );

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.isSelected(testItem), isTrue);

      provider.setSelectionMode(false);
      expect(provider.isSelectionMode, isFalse);
    });

    test('JavmostBrowseProvider selection', () {
      final provider = JavmostBrowseProvider(autoLoad: false);
      final testItem = VideoItem(
        title: 'Test JM',
        detailUrl: 'https://www.javmost.ws/xyz/',
        slug: 'https://www.javmost.ws/xyz/',
        date: '',
        author: '',
      );

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.isSelected(testItem), isTrue);

      provider.toggleItemSelection(testItem);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedCount, equals(0));
    });
  });

  group('Stream Resolver Unit Tests', () {
    test('JavguruApiService.unpackDeanEdwards decodes packed script properly', () {
      const packed = "}('0 1=2;',3,3,'var|a|5'.split('|'))";
      final unpacked = JavguruApiService.unpackDeanEdwards(packed);
      expect(unpacked, equals('var a=5;'));
    });

    test('JavguruApiService.resolveStreamUrl returns m3u8 directly if already stream url', () async {
      const direct = 'https://example.com/playlist.m3u8';
      final res = await JavguruApiService.resolveStreamUrl(direct);
      expect(res, equals(direct));
    });

    test('Av123ApiService.resolveStreamUrl returns m3u8 directly if already stream url', () async {
      const direct = 'https://example.com/video.m3u8';
      final res = await Av123ApiService.resolveStreamUrl(direct);
      expect(res, equals(direct));
    });

    test('JavmostApiService.resolveStreamUrl returns m3u8 directly if already stream url', () async {
      const direct = 'https://example.com/stream.m3u8';
      final res = await JavmostApiService.resolveStreamUrl(direct);
      expect(res, equals(direct));
    });
  });
}
