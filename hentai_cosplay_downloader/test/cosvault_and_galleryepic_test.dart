import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/models/resource_site_item.dart';
import 'package:hentai_cosplay_downloader/providers/gallery_provider.dart';
import 'package:hentai_cosplay_downloader/services/cosvault/cosvault_api_service.dart';
import 'package:hentai_cosplay_downloader/services/galleryepic/galleryepic_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = null;
  });

  group('CosVault & GalleryEpic Integration Tests', () {
    test('MediaSourceType and AlbumItem.inferSource test', () {
      final cvAlbum = AlbumItem.fromJson({
        'title': 'Atsuki Test',
        'slug': 'cv_123',
        'detailUrl': 'https://cosvault.top/p/atsuki-10424/',
      });
      expect(cvAlbum.sourceType, equals(MediaSourceType.cosvault));

      final geAlbum = AlbumItem.fromJson({
        'title': 'Cheshire Test',
        'slug': 'ge_123',
        'detailUrl': 'https://galleryepic.xyz/zh/cosplay/10438',
      });
      expect(geAlbum.sourceType, equals(MediaSourceType.galleryepic));
    });

    test('ResourceSiteRegistry includes cosvault and galleryepic', () {
      expect(ResourceSiteRegistry.allSites.containsKey('cosvault'), isTrue);
      expect(ResourceSiteRegistry.allSites.containsKey('galleryepic'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('cosvault'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('galleryepic'), isTrue);

      final ordered = ResourceSiteRegistry.getOrderedSites(null);
      final keys = ordered.map((s) => s.key).toList();
      expect(keys.contains('cosvault'), isTrue);
      expect(keys.contains('galleryepic'), isTrue);

      // Test hiddenKeys filtering
      final filtered = ResourceSiteRegistry.getOrderedSites(null, hiddenKeys: ['cosvault', 'mzt']);
      final filteredKeys = filtered.map((s) => s.key).toList();
      expect(filteredKeys.contains('cosvault'), isFalse);
      expect(filteredKeys.contains('mzt'), isFalse);
      expect(filteredKeys.contains('galleryepic'), isTrue);
    });

    test('AppConfig hiddenResourceSites serialization test', () {
      final config = AppConfig(
        hiddenResourceSites: ['cosvault', 'xvideos'],
      );
      final json = config.toJson();
      expect(json['hiddenResourceSites'], equals(['cosvault', 'xvideos']));

      final restored = AppConfig.fromJson(json);
      expect(restored.hiddenResourceSites, equals(['cosvault', 'xvideos']));
    });

    test('GallerySourceFilter has cosvault and galleryepic', () {
      expect(
        GallerySourceFilter.values.any((f) => f.sourceType == MediaSourceType.cosvault),
        isTrue,
      );
      expect(
        GallerySourceFilter.values.any((f) => f.sourceType == MediaSourceType.galleryepic),
        isTrue,
      );
    });

    test('CosvaultApiService URL construction and alias mapping', () {
      expect(CosvaultApiService.buildUrl(page: 1), equals('https://cosvault.top/posts/'));
      expect(CosvaultApiService.buildUrl(page: 3), equals('https://cosvault.top/posts/page/3/'));
      expect(
        CosvaultApiService.buildUrl(page: 1, keyword: 'atsuki'),
        equals('https://cosvault.top/tags/atsuki/'),
      );
      expect(CosvaultApiService.resolveTagSlug('原神'), equals('genshin-impact'));
      expect(CosvaultApiService.resolveTagSlug('genshin'), equals('genshin-impact'));
      expect(CosvaultApiService.resolveTagSlug('miku'), equals('hatsune-miku'));
      expect(CosvaultApiService.resolveTagSlug('碧蓝航线'), equals('azur-lane'));
      expect(
        CosvaultApiService.buildUrl(page: 1, keyword: '原神'),
        equals('https://cosvault.top/tags/genshin-impact/'),
      );
      expect(
        CosvaultApiService.buildUrl(page: 1, modelSlug: 'atsuki'),
        equals('https://cosvault.top/models/atsuki/'),
      );
    });

    test('GalleryepicApiService URL construction', () {
      expect(
        GalleryepicApiService.buildUrl(page: 1, category: GalleryEpicCategory.cosplay),
        equals('https://galleryepic.xyz/zh/cosplays/1'),
      );
      expect(
        GalleryepicApiService.buildUrl(page: 2, category: GalleryEpicCategory.albums),
        equals('https://galleryepic.xyz/zh/albums/2'),
      );
      expect(
        GalleryepicApiService.buildUrl(page: 1, customPath: '/zh/character/1'),
        equals('https://galleryepic.xyz/zh/character/1'),
      );
      expect(
        GalleryepicApiService.buildUrl(page: 2, customPath: '/zh/coser/453/1'),
        equals('https://galleryepic.xyz/zh/coser/453/2'),
      );
    });

    test('Live fetch CosVault page 1 test', () async {
      CosvaultApiService.setProxy(null);
      final data = await CosvaultApiService.fetchPageData(page: 1);
      if (data != null) {
        expect(data.items, isNotEmpty);
        expect(data.page, equals(1));
        expect(data.totalPages, greaterThan(1));
        final first = data.items.first;
        expect(first.title, isNotEmpty);
        expect(first.detailUrl, contains('cosvault.top/p/'));
        // ignore: avoid_print
        print('CosVault page 1 success: ${data.items.length} items. First: "${first.title}"');

        // Test detail fetching
        final detailed = await CosvaultApiService.fetchAlbumDetail(first);
        expect(detailed, isNotNull);
        expect(detailed!.imageUrls, isNotEmpty);
        // ignore: avoid_print
        print('CosVault detail success: ${detailed.imageUrls.length} images.');
      }
    });

    test('Live fetch GalleryEpic page 1 test', () async {
      GalleryepicApiService.setProxy(null);
      final data = await GalleryepicApiService.fetchPageData(page: 1, category: GalleryEpicCategory.cosplay);
      if (data != null) {
        expect(data.items, isNotEmpty);
        expect(data.page, equals(1));
        final first = data.items.first;
        expect(first.title, isNotEmpty);
        expect(first.detailUrl, contains('galleryepic.xyz/zh/cosplay/'));
        // ignore: avoid_print
        print('GalleryEpic page 1 success: ${data.items.length} items. First: "${first.title}"');

        // Test detail fetching
        final detailed = await GalleryepicApiService.fetchAlbumDetail(first);
        expect(detailed, isNotNull);
        expect(detailed!.imageUrls, isNotEmpty);
        // ignore: avoid_print
        print('GalleryEpic detail success: ${detailed.imageUrls.length} images.');
      }
    });
  });
}
