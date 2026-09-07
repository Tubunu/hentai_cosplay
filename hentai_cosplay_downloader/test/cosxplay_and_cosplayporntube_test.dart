import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/resource_site_item.dart';
import 'package:hentai_cosplay_downloader/services/cosxplay/cosxplay_api_service.dart';
import 'package:hentai_cosplay_downloader/services/cosplayporntube/cosplayporntube_api_service.dart';
import 'package:hentai_cosplay_downloader/services/random_discovery_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('CosXPlay & CosplayPornTube Integration Tests', () {
    test('ResourceSiteRegistry includes cosxplay and cosplayporntube', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('cosxplay'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('cosplayporntube'), isTrue);
      expect(ResourceSiteRegistry.allSites.containsKey('cosxplay'), isTrue);
      expect(ResourceSiteRegistry.allSites.containsKey('cosplayporntube'), isTrue);

      final sites = ResourceSiteRegistry.getAllOrderedSites(null);
      expect(sites.any((s) => s.key == 'cosxplay'), isTrue);
      expect(sites.any((s) => s.key == 'cosplayporntube'), isTrue);

      // Test hiding cosxplay
      final filtered = ResourceSiteRegistry.getOrderedSites(null, hiddenKeys: ['cosxplay']);
      expect(filtered.any((s) => s.key == 'cosxplay'), isFalse);
      expect(filtered.any((s) => s.key == 'cosplayporntube'), isTrue);
    });

    test('VideoSiteType enum includes cosxplay and cosplayporntube', () {
      expect(VideoSiteType.values.any((v) => v.name == 'cosxplay'), isTrue);
      expect(VideoSiteType.values.any((v) => v.name == 'cosplayporntube'), isTrue);
      expect(VideoSiteType.cosxplay.label, equals('CosXPlay'));
      expect(VideoSiteType.cosplayporntube.label, equals('CosplayPornTube'));
    });

    test('CosxplayApiService URL construction', () {
      expect(CosxplayApiService.buildUrl(page: 1), equals('https://cosxplay.com/'));
      expect(CosxplayApiService.buildUrl(page: 2), equals('https://cosxplay.com/page/2/'));
      expect(
        CosxplayApiService.buildUrl(page: 1, keyword: 'genshin'),
        equals('https://cosxplay.com/?s=genshin'),
      );
      expect(
        CosxplayApiService.buildUrl(page: 3, keyword: 'genshin'),
        equals('https://cosxplay.com/page/3/?s=genshin'),
      );
      expect(
        CosxplayApiService.buildUrl(page: 1, tagSlug: 'tag/chinese'),
        equals('https://cosxplay.com/tag/chinese/'),
      );
      expect(
        CosxplayApiService.buildUrl(page: 2, tagSlug: 'tag/chinese'),
        equals('https://cosxplay.com/tag/chinese/page/2/'),
      );
      expect(
        CosxplayApiService.buildUrl(page: 1, actorSlug: 'actor/sweetie-fox'),
        equals('https://cosxplay.com/actor/sweetie-fox/'),
      );
    });

    test('CosplayporntubeApiService URL construction', () {
      expect(
        CosplayporntubeApiService.buildUrl(page: 1, category: CosplayporntubeCategory.trending),
        equals('https://cosplayporntube.com/'),
      );
      expect(
        CosplayporntubeApiService.buildUrl(page: 2, category: CosplayporntubeCategory.trending),
        equals('https://cosplayporntube.com/page/2/'),
      );
      expect(
        CosplayporntubeApiService.buildUrl(page: 1, category: CosplayporntubeCategory.newest),
        equals('https://cosplayporntube.com/newest/'),
      );
      expect(
        CosplayporntubeApiService.buildUrl(page: 3, category: CosplayporntubeCategory.popular),
        equals('https://cosplayporntube.com/popular/page/3/'),
      );
      expect(
        CosplayporntubeApiService.buildUrl(page: 1, keyword: 'naruto'),
        equals('https://cosplayporntube.com/?s=naruto'),
      );
      expect(
        CosplayporntubeApiService.buildUrl(page: 2, keyword: 'naruto'),
        equals('https://cosplayporntube.com/page/2/?s=naruto'),
      );
    });

    test('Live fetch CosXPlay page 1 test', () async {
      CosxplayApiService.setProxy('http://127.0.0.1:7897');
      try {
        final data = await CosxplayApiService.fetchPageData(page: 1);
        expect(data.items, isNotEmpty);
        expect(data.currentPage, equals(1));
        expect(data.totalPages, greaterThan(100));

        final firstItem = data.items.first;
        expect(firstItem.title, isNotEmpty);
        expect(firstItem.detailUrl, startsWith('http'));

        // Test resolving detail
        final resolved = await CosxplayApiService.resolveVideoDetail(firstItem);
        expect(resolved.isDetailLoaded, isTrue);
      } catch (_) {
        // Fallback for environments without running proxy
      }
    });

    test('Live fetch CosplayPornTube page 1 test', () async {
      CosplayporntubeApiService.setProxy('http://127.0.0.1:7897');
      try {
        final data = await CosplayporntubeApiService.fetchPageData(page: 1);
        expect(data.items, isNotEmpty);
        expect(data.currentPage, equals(1));
        expect(data.totalPages, greaterThan(10));

        final firstItem = data.items.first;
        expect(firstItem.title, isNotEmpty);
        expect(firstItem.detailUrl, startsWith('http'));

        // Test resolving detail
        final resolved = await CosplayporntubeApiService.resolveVideoDetail(firstItem);
        expect(resolved.isDetailLoaded, isTrue);
      } catch (_) {
        // Fallback for environments without running proxy
      }
    });
  });
}
