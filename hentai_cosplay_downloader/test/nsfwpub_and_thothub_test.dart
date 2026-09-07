import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/album_item.dart';
import 'package:hentai_cosplay_downloader/models/resource_site_item.dart';
import 'package:hentai_cosplay_downloader/services/random_discovery_service.dart';
import 'package:hentai_cosplay_downloader/services/nsfwpub/nsfwpub_api_service.dart';
import 'package:hentai_cosplay_downloader/services/thothub/thothub_api_service.dart';
import 'package:hentai_cosplay_downloader/providers/nsfwpub_browse_provider.dart';
import 'package:hentai_cosplay_downloader/providers/thothub_browse_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResourceSiteRegistry Integration Tests', () {
    test('defaultOrder contains nsfwpub and thothub', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('nsfwpub'), isTrue);
      expect(ResourceSiteRegistry.defaultOrder.contains('thothub'), isTrue);
    });

    test('allSites contains nsfwpub and thothub with proper metadata', () {
      final nfp = ResourceSiteRegistry.allSites['nsfwpub'];
      expect(nfp, isNotNull);
      expect(nfp!.label, equals('NSFWPub'));
      expect(nfp.key, equals('nsfwpub'));

      final th = ResourceSiteRegistry.allSites['thothub'];
      expect(th, isNotNull);
      expect(th!.label, equals('Thothub'));
      expect(th.key, equals('thothub'));
    });

    test('getOrderedSites handles ordering and hiding correctly', () {
      final all = ResourceSiteRegistry.getOrderedSites(null);
      expect(all.any((s) => s.key == 'nsfwpub'), isTrue);
      expect(all.any((s) => s.key == 'thothub'), isTrue);

      final hidden = ResourceSiteRegistry.getOrderedSites(null, hiddenKeys: ['nsfwpub', 'thothub']);
      expect(hidden.any((s) => s.key == 'nsfwpub'), isFalse);
      expect(hidden.any((s) => s.key == 'thothub'), isFalse);
    });
  });

  group('MediaSourceType & VideoSiteType Enum Tests', () {
    test('MediaSourceType enum contains nsfwpub', () {
      expect(MediaSourceType.values.any((e) => e.name == 'nsfwpub'), isTrue);
      expect(MediaSourceType.nsfwpub.label, equals('NSFWPub'));
      expect(MediaSourceType.nsfwpub.badge, equals('NFP'));
    });

    test('AlbumItem.inferSource identifies nsfwpub correctly', () {
      final s1 = AlbumItem.inferSource(detailUrl: 'https://nsfwpub.com/pics/103248');
      expect(s1, equals(MediaSourceType.nsfwpub));

      final s2 = AlbumItem.inferSource(sourceTypeName: 'nsfwpub');
      expect(s2, equals(MediaSourceType.nsfwpub));
    });

    test('VideoSiteType enum contains thothub', () {
      expect(VideoSiteType.values.any((e) => e.name == 'thothub'), isTrue);
      expect(VideoSiteType.thothub.label, equals('Thothub'));
    });
  });

  group('NsfwpubApiService URL Builder Tests', () {
    test('buildUrl all / home', () {
      expect(
        NsfwpubApiService.buildUrl(page: 1, category: NsfwpubCategory.all),
        equals('https://nsfwpub.com/'),
      );
      expect(
        NsfwpubApiService.buildUrl(page: 2, category: NsfwpubCategory.all),
        equals('https://nsfwpub.com/?page=2'),
      );
    });

    test('buildUrl category', () {
      expect(
        NsfwpubApiService.buildUrl(page: 1, category: NsfwpubCategory.cosplay),
        equals('https://nsfwpub.com/category/cosplay'),
      );
      expect(
        NsfwpubApiService.buildUrl(page: 3, category: NsfwpubCategory.cosplay),
        equals('https://nsfwpub.com/category/cosplay?page=3'),
      );
      expect(
        NsfwpubApiService.buildUrl(page: 1, category: NsfwpubCategory.asian),
        equals('https://nsfwpub.com/category/asian'),
      );
    });

    test('buildUrl search', () {
      expect(
        NsfwpubApiService.buildUrl(page: 1, keyword: 'genshin impact'),
        equals('https://nsfwpub.com/search/genshin%20impact'),
      );
      expect(
        NsfwpubApiService.buildUrl(page: 2, keyword: 'genshin impact'),
        equals('https://nsfwpub.com/search/genshin%20impact?page=2'),
      );
    });
  });

  group('ThothubApiService URL Builder Tests', () {
    test('buildUrl categories', () {
      expect(
        ThothubApiService.buildUrl(page: 1, category: ThothubCategory.latest),
        equals('https://thothub.to/latest-updates/'),
      );
      expect(
        ThothubApiService.buildUrl(page: 2, category: ThothubCategory.latest),
        equals('https://thothub.to/latest-updates/2/'),
      );
      expect(
        ThothubApiService.buildUrl(page: 1, category: ThothubCategory.popular),
        equals('https://thothub.to/most-popular/'),
      );
      expect(
        ThothubApiService.buildUrl(page: 4, category: ThothubCategory.popular),
        equals('https://thothub.to/most-popular/4/'),
      );
    });

    test('buildUrl search', () {
      expect(
        ThothubApiService.buildUrl(page: 1, keyword: 'cosplay'),
        equals('https://thothub.to/search/cosplay/'),
      );
      expect(
        ThothubApiService.buildUrl(page: 2, keyword: 'cosplay'),
        equals('https://thothub.to/search/cosplay/2/'),
      );
    });
  });

  group('Provider Unit Tests', () {
    test('NsfwpubBrowseProvider initial state and selection toggling', () {
      final provider = NsfwpubBrowseProvider();
      expect(provider.items, isEmpty);
      expect(provider.currentPage, equals(1));
      expect(provider.currentCategory, equals(NsfwpubCategory.all));
      expect(provider.isSelectionMode, isFalse);

      final dummyItem = AlbumItem(
        title: 'Test NSFWPub Album',
        slug: '12345',
        detailUrl: 'https://nsfwpub.com/pics/12345',
        date: '2026-09-03',
        author: 'ModelName',
      );

      provider.toggleItemSelection(dummyItem);
      expect(provider.isSelectionMode, isTrue);
      expect(provider.isSelected(dummyItem), isTrue);
      expect(provider.selectedCount, equals(1));

      provider.toggleItemSelection(dummyItem);
      expect(provider.isSelectionMode, isFalse);
      expect(provider.isSelected(dummyItem), isFalse);
      expect(provider.selectedCount, equals(0));
    });

    test('ThothubBrowseProvider initial state and category switching', () {
      final provider = ThothubBrowseProvider();
      expect(provider.items, isEmpty);
      expect(provider.currentPage, equals(1));
      expect(provider.currentCategory, equals(ThothubCategory.latest));
      expect(provider.isSelectionMode, isFalse);
    });
  });
}
