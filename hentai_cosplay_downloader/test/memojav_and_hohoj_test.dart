import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/ui/site_registry.dart';
import 'package:hentai_cosplay_downloader/providers/memojav_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/hohoj_browse_provider.dart';
import 'package:hentai_cosplay_downloader/services/memojav/memojav_api_service.dart';
import 'package:hentai_cosplay_downloader/services/hohoj/hohoj_api_service.dart';
import 'package:hentai_cosplay_downloader/services/random_discovery_service.dart';
import 'package:hentai_cosplay_downloader/models/favorite_item.dart';
import 'package:hentai_cosplay_downloader/models/video_item.dart';

void main() {
  group('ResourceSiteRegistry MemoJAV & HoHoJ Integration Tests', () {
    test('defaultOrder contains memojav and hohoj', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('memojav'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('hohoj'), isTrue);
    });

    test('allSites contains memojav and hohoj with valid metadata and builders', () {
      final memojavSite = ResourceSiteRegistry.allSites['memojav'];
      expect(memojavSite, isNotNull);
      expect(memojavSite!.key, equals('memojav'));
      expect(memojavSite.label, equals('MemoJAV'));
      expect(memojavSite.color, equals(const Color(0xFF6C5CE7)));

      final hohojSite = ResourceSiteRegistry.allSites['hohoj'];
      expect(hohojSite, isNotNull);
      expect(hohojSite!.key, equals('hohoj'));
      expect(hohojSite.label, equals('HoHoJ'));
      expect(hohojSite.color, equals(const Color(0xFFE74C3C)));
    });

    test('getOrderedSites includes memojav and hohoj', () {
      final ordered = ResourceSiteRegistry.getOrderedSites(null);
      final keys = ordered.map((e) => e.key).toList();
      expect(keys.contains('memojav'), isTrue);
      expect(keys.contains('hohoj'), isTrue);
    });
  });

  group('VideoSiteType Enum Tests for MemoJAV & HoHoJ', () {
    test('VideoSiteType enum contains memojav and hohoj', () {
      expect(VideoSiteType.values.any((e) => e.name == 'memojav'), isTrue);
      expect(VideoSiteType.values.any((e) => e.name == 'hohoj'), isTrue);
      expect(VideoSiteType.memojav.label, equals('MemoJAV'));
      expect(VideoSiteType.hohoj.label, equals('HoHoJ'));
    });
  });

  group('MemojavApiService URL Builder & Parser Tests', () {
    test('buildUrl catalog', () {
      expect(
        MemojavApiService.buildUrl(page: 1, category: MemojavCategory.best),
        equals('https://memojav.org/best/'),
      );
      expect(
        MemojavApiService.buildUrl(page: 2, category: MemojavCategory.best),
        equals('https://memojav.org/best/page-2'),
      );
      expect(
        MemojavApiService.buildUrl(page: 1, category: MemojavCategory.latest),
        equals('https://memojav.org/video/'),
      );
      expect(
        MemojavApiService.buildUrl(page: 3, category: MemojavCategory.latest),
        equals('https://memojav.org/video/page-3'),
      );
    });

    test('buildUrl search by keyword', () {
      expect(
        MemojavApiService.buildUrl(keyword: 'jur-511'),
        equals('https://memojav.org/video/JUR-511'),
      );
    });

    test('parseListPageHtml extracts video items, metadata and pagination', () {
      const sampleHtml = '''
      <div id="relative-video" class="flexw">
        <a href="/video/JUR-511" class="video-item">
          <img class="video-poster" alt="JUR-511 POSTER Intimate Sex" src="https://pics.dmm.co.jp/digital/video/jur00511/jur00511pl.jpg">
          <div class="video-metadata">JUR-511 • MADONNA • Meguri</div>
          <div class="video-title f16500">Intimate Sex - Meguri</div>
        </a>
        <a href="/video/FNS-114" class="video-item">
          <img class="video-poster" alt="FNS-114 POSTER Rin Yamitsu" src="https://memojav.org/image/preview/1fns00114/1fns00114pl.jpg">
          <div class="video-metadata">FNS-114 • FALENO • Rin</div>
          <div class="video-title f16500">On the way home</div>
        </a>
      </div>
      <input type="number" class="inputNumber_nav input f16500" value="1" max="25">
      <ul class="pageNav-main flexjw">
        <li class="pageNav-page pageNav-page--current"><a href="page-1">1</a></li>
        <li class="pageNav-page"><a href="page-2">2</a></li>
        <li class="pageNav-page"><a href="page-25">25</a></li>
      </ul>
      ''';

      final pageData = MemojavApiService.parseListPageHtmlForTest(sampleHtml, 1);
      expect(pageData.items.length, equals(2));

      final first = pageData.items[0];
      expect(first.slug, equals('JUR-511'));
      expect(first.title, equals('Intimate Sex - Meguri'));
      expect(first.coverUrl, equals('https://pics.dmm.co.jp/digital/video/jur00511/jur00511pl.jpg'));
      expect(first.author, equals('MemoJAV'));
      expect(first.rawData['metadata'], equals('JUR-511 • MADONNA • Meguri'));

      final second = pageData.items[1];
      expect(second.slug, equals('FNS-114'));
      expect(second.title, equals('On the way home'));

      expect(pageData.totalPages, equals(25));
    });
  });

  group('HohojApiService URL Builder & Parser Tests', () {
    test('buildUrl catalog with types and orders', () {
      expect(
        HohojApiService.buildUrl(
          page: 1,
          category: HohojCategory.all,
          order: HohojOrder.popular,
        ),
        equals('https://hohoj.tv/search?type=all&order=popular&p=1'),
      );
      expect(
        HohojApiService.buildUrl(
          page: 2,
          category: HohojCategory.chinese,
          order: HohojOrder.latest,
        ),
        equals('https://hohoj.tv/search?type=chinese&order=latest&p=2'),
      );
      expect(
        HohojApiService.buildUrl(
          page: 1,
          category: HohojCategory.uncensored,
          order: HohojOrder.views,
        ),
        equals('https://hohoj.tv/search?type=uncensored&order=views&p=1'),
      );
    });

    test('buildUrl search', () {
      expect(
        HohojApiService.buildUrl(page: 1, keyword: 'GARA-026'),
        equals('https://hohoj.tv/search?text=GARA-026&p=1'),
      );
    });

    test('parseListPageHtml extracts cards, views, likes, badges, and cover', () {
      const sampleHtml = '''
      <div class="video-list">
        <div class="row">
          <div class="video-item col-lg-3 col-md-3 col-sm-6 col-6 mt-4">
            <a href="/video?id=59247">
              <img class="img-placeholder" src="https://cdn-1.ggjav.com/media/video/small_321145.jpg" alt="GARA-026 絕叫淩●擊●姦">
              <div class="video-item-title mt-1">GARA-026 絕叫淩●擊●姦 一條未央</div>
              <div class="video-item-rating mt-1">
                <i class="fa-regular fa-eye"></i>
                <span class="me-2">29.2 k</span>
                <i class="fa-regular fa-heart"></i>
                <span>17</span>
              </div>
              <div class="video-item-badge">中文字幕</div>
            </a>
          </div>
          <div class="video-item col-lg-3 col-md-3 col-sm-6 col-6 mt-4">
            <a href="/video?id=44775">
              <img class="img-placeholder" src="https://cdn-1.ggjav.com/media/video/small_306814.jpg" alt="VENX-356 北野未奈">
              <div class="video-item-title mt-1">VENX-356 北野未奈</div>
              <div class="video-item-rating mt-1">
                <i class="fa-regular fa-eye"></i>
                <span class="me-2">742.6 k</span>
                <i class="fa-regular fa-heart"></i>
                <span>1.0 k</span>
              </div>
              <div class="video-item-badge">無碼</div>
            </a>
          </div>
        </div>
      </div>
      ''';

      final pageData = HohojApiService.parseListPageHtmlForTest(sampleHtml, 1);
      expect(pageData.items.length, equals(2));

      final first = pageData.items[0];
      expect(first.slug, equals('59247'));
      expect(first.title, equals('GARA-026 絕叫淩●擊●姦 一條未央'));
      expect(first.coverUrl, equals('https://cdn-1.ggjav.com/media/video/small_321145.jpg'));
      expect(first.views, equals('29.2 k'));
      expect(first.tags, contains('中文字幕'));
      expect(first.rawData['likes'], equals('17'));
      expect(first.rawData['badge'], equals('中文字幕'));

      final second = pageData.items[1];
      expect(second.slug, equals('44775'));
      expect(second.title, equals('VENX-356 北野未奈'));
      expect(second.views, equals('742.6 k'));
      expect(second.tags, contains('無碼'));
    });
  });

  group('BrowseProvider State Tests', () {
    test('MemojavBrowseProvider initial state and selection operations', () {
      final provider = MemojavBrowseProvider(autoLoad: false);
      expect(provider.currentPage, equals(1));
      expect(provider.currentCategory, equals(MemojavCategory.best));
      expect(provider.isSelectionMode, isFalse);
      expect(provider.selectedSlugs.isEmpty, isTrue);

      provider.setSelectionMode(true);
      expect(provider.isSelectionMode, isTrue);

      provider.setSelectionMode(false);
      expect(provider.isSelectionMode, isFalse);
      provider.dispose();
    });

    test('HohojBrowseProvider initial state and order selection', () {
      final provider = HohojBrowseProvider(autoLoad: false);
      expect(provider.currentPage, equals(1));
      expect(provider.currentCategory, equals(HohojCategory.all));
      expect(provider.currentOrder, equals(HohojOrder.popular));
      expect(provider.isSelectionMode, isFalse);
      provider.dispose();
    });
  });

  group('FavoriteItem Integration Tests for MemoJAV & HoHoJ', () {
    test('FavoriteItem.fromVideo correctly identifies MemoJAV', () {
      final item = VideoItem(
        title: 'Test MemoJAV Video',
        slug: 'TEST-123',
        detailUrl: 'https://memojav.org/video/TEST-123',
        coverUrl: 'https://memojav.org/cover.jpg',
        date: '2024-01-01',
        author: 'MemoJAV',
      );
      final fav = FavoriteItem.fromVideo(item);
      expect(fav.siteKey, equals('memojav'));
      expect(fav.siteName, equals('MemoJAV'));
      expect(fav.siteColorValue, equals(0xFF6C5CE7));
      expect(fav.id, equals('memojav_TEST-123'));
    });

    test('FavoriteItem.fromVideo correctly identifies HoHoJ', () {
      final item = VideoItem(
        title: 'Test HoHoJ Video',
        slug: '59247',
        detailUrl: 'https://hohoj.tv/video?id=59247',
        coverUrl: 'https://cdn-1.ggjav.com/media/video/small_321145.jpg',
        date: '2024-01-01',
        author: 'HoHoJ',
      );
      final fav = FavoriteItem.fromVideo(item);
      expect(fav.siteKey, equals('hohoj'));
      expect(fav.siteName, equals('HoHoJ'));
      expect(fav.siteColorValue, equals(0xFFE74C3C));
      expect(fav.id, equals('hohoj_59247'));
    });
  });
}
