import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/resource_site_item.dart';
import 'package:hentai_cosplay_downloader/providers/pornhub_author_provider.dart';
import 'package:hentai_cosplay_downloader/providers/xvideos_author_provider.dart';
import 'package:hentai_cosplay_downloader/services/xvideos/xvideos_api_service.dart';

void main() {
  group('XVideosApiService URL and Routing tests', () {
    test('ResourceSiteRegistry contains xvideos', () {
      expect(ResourceSiteRegistry.defaultOrder.contains('xvideos'), isTrue);
      expect(ResourceSiteRegistry.allSites.containsKey('xvideos'), isTrue);
      final item = ResourceSiteRegistry.allSites['xvideos'];
      expect(item, isNotNull);
      expect(item!.label, 'XVideos');
      expect(item.key, 'xvideos');
    });

    test('Latest Videos URL (最新发布)', () {
      // Page 1
      expect(
        XVideosApiService.buildUrl(mainMode: XVideosMainMode.latest, page: 1),
        'https://www.xvideos.com/',
      );
      // Page 2
      expect(
        XVideosApiService.buildUrl(mainMode: XVideosMainMode.latest, page: 2),
        'https://www.xvideos.com/new/1',
      );
      // Page 3
      expect(
        XVideosApiService.buildUrl(mainMode: XVideosMainMode.latest, page: 3),
        'https://www.xvideos.com/new/2',
      );
    });

    test('Best Videos URL (最佳影片) with month selection', () {
      // Page 1 of month
      expect(
        XVideosApiService.buildUrl(
          mainMode: XVideosMainMode.best,
          selectedMonth: '2026-07',
          page: 1,
        ),
        'https://www.xvideos.com/best/2026-07',
      );
      // Page 2 of month
      expect(
        XVideosApiService.buildUrl(
          mainMode: XVideosMainMode.best,
          selectedMonth: '2026-07',
          page: 2,
        ),
        'https://www.xvideos.com/best/2026-07/1',
      );
      // Page 3 of month
      expect(
        XVideosApiService.buildUrl(
          mainMode: XVideosMainMode.best,
          selectedMonth: '2026-07',
          page: 3,
        ),
        'https://www.xvideos.com/best/2026-07/2',
      );
    });

    test('Type 1 Category (Canonical, e.g. Asian_Woman-32) with sub-sorting', () {
      const asianCat = XVideosCategoryItem(
        id: 'asian',
        name: '亚洲 (Asian Woman)',
        path: 'Asian_Woman-32',
        type: XVideosCategoryType.canonical,
      );

      // Default (关闭)
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.none, page: 1),
        'https://www.xvideos.com/c/Asian_Woman-32',
      );
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.none, page: 2),
        'https://www.xvideos.com/c/Asian_Woman-32/1',
      );

      // Latest (最新 uploaddate)
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.latest, page: 1),
        'https://www.xvideos.com/c/s:uploaddate/Asian_Woman-32',
      );
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.latest, page: 2),
        'https://www.xvideos.com/c/s:uploaddate/Asian_Woman-32/1',
      );

      // Rating (评级 rating)
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.rating, page: 1),
        'https://www.xvideos.com/c/s:rating/Asian_Woman-32',
      );
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.rating, page: 2),
        'https://www.xvideos.com/c/s:rating/Asian_Woman-32/1',
      );

      // Views (观看次数 views)
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.views, page: 1),
        'https://www.xvideos.com/c/s:views/Asian_Woman-32',
      );
      expect(
        XVideosApiService.buildUrl(category: asianCat, subSort: XVideosSubSort.views, page: 2),
        'https://www.xvideos.com/c/s:views/Asian_Woman-32/1',
      );
    });

    test('Type 2 Category (Search Tag, e.g. cosplay) with sub-sorting', () {
      const cosplayCat = XVideosCategoryItem(
        id: 'cosplay',
        name: 'Cosplay',
        path: 'cosplay',
        type: XVideosCategoryType.searchTag,
      );

      // Default (关闭)
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.none, page: 1),
        'https://www.xvideos.com/?k=cosplay&top',
      );
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.none, page: 2),
        'https://www.xvideos.com/?k=cosplay&top&p=1',
      );

      // Latest (最新 uploaddate)
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.latest, page: 1),
        'https://www.xvideos.com/?k=cosplay&sort=uploaddate',
      );
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.latest, page: 2),
        'https://www.xvideos.com/?k=cosplay&sort=uploaddate&p=1',
      );

      // Rating (评级 rating)
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.rating, page: 1),
        'https://www.xvideos.com/?k=cosplay&sort=rating',
      );
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.rating, page: 2),
        'https://www.xvideos.com/?k=cosplay&sort=rating&p=1',
      );

      // Views (观看次数 views)
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.views, page: 1),
        'https://www.xvideos.com/?k=cosplay&sort=views',
      );
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.views, page: 2),
        'https://www.xvideos.com/?k=cosplay&sort=views&p=1',
      );

      // Random (随机 random)
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.random, page: 1),
        'https://www.xvideos.com/?k=cosplay&sort=random',
      );
      expect(
        XVideosApiService.buildUrl(category: cosplayCat, subSort: XVideosSubSort.random, page: 2),
        'https://www.xvideos.com/?k=cosplay&sort=random&p=1',
      );
    });

    test('Search Keyword with sub-sorting', () {
      // Default search
      expect(
        XVideosApiService.buildUrl(keyword: 'genshin impact', subSort: XVideosSubSort.none, page: 1),
        'https://www.xvideos.com/?k=genshin%20impact&top',
      );
      expect(
        XVideosApiService.buildUrl(keyword: 'genshin', subSort: XVideosSubSort.latest, page: 2),
        'https://www.xvideos.com/?k=genshin&sort=uploaddate&p=1',
      );
      expect(
        XVideosApiService.buildUrl(keyword: 'genshin', subSort: XVideosSubSort.views, page: 3),
        'https://www.xvideos.com/?k=genshin&sort=views&p=2',
      );
    });

    test('XVideosAuthorProvider and PornhubAuthorProvider initialization', () {
      final xProv = XVideosAuthorProvider(
        authorName: 'Sweetie Fox',
        authorUrl: 'https://www.xvideos.com/channels/sweetie_fox',
      );
      expect(xProv.authorName, 'Sweetie Fox');
      expect(xProv.authorUrl, 'https://www.xvideos.com/channels/sweetie_fox');
      expect(xProv.currentPage, 1);
      expect(xProv.subSort, XVideosSubSort.none);

      final pProv = PornhubAuthorProvider(
        authorName: 'Eva Elfie',
        authorUrl: 'https://cn.pornhub.com/model/eva-elfie',
      );
      expect(pProv.authorName, 'Eva Elfie');
      expect(pProv.authorUrl, 'https://cn.pornhub.com/model/eva-elfie');
      expect(pProv.currentPage, 1);
    });
  });
}
