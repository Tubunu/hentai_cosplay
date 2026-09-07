import 'dart:math';
import 'package:flutter/material.dart';
import '../models/album_item.dart';
import 'coomer/coomer_api_service.dart';
import 'cosplaytele/cosplaytele_api_service.dart';
import 'cosvault/cosvault_api_service.dart';
import 'eporner/eporner_api_service.dart';
import 'exhentai/exhentai_api_service.dart';
import 'galleryepic/galleryepic_api_service.dart';
import 'hanime1/hanime1_api_service.dart';
import 'hc_api_service.dart';
import 'hqporner/hqporner_api_service.dart';
import 'iwara/iwara_api_service.dart';
import 'kuraa/kuraa_api_service.dart';
import 'misskon/misskon_api_service.dart';
import 'mzt_api_service.dart';
import 'nucosplay/nucosplay_api_service.dart';
import 'pinse/pinse_api_service.dart';
import 'pixibb/pixibb_api_service.dart';
import 'pornbox/pornbox_api_service.dart';
import 'pornhub/pornhub_api_service.dart';
import 'rule34video/rule34video_api_service.dart';
import 'spankbang/spankbang_api_service.dart';
import 'video_api_service.dart';
import 'xvideos/xvideos_api_service.dart';
import 'cosxplay/cosxplay_api_service.dart';
import 'cosplayporntube/cosplayporntube_api_service.dart';
import 'xhamster/xhamster_api_service.dart';
import 'xnxx/xnxx_api_service.dart';
import 'nsfwpub/nsfwpub_api_service.dart';
import 'thothub/thothub_api_service.dart';
import 'njav/njav_api_service.dart';
import 'vjav/vjav_api_service.dart';
import 'javguru/javguru_api_service.dart';
import 'av123/av123_api_service.dart';
import 'javmost/javmost_api_service.dart';

import '../ui/pages/browse/album_detail_page.dart';
import '../ui/pages/coomer/coomer_detail_page.dart';
import '../ui/pages/cosplaytele/cosplaytele_detail_page.dart';
import '../ui/pages/cosvault/cosvault_detail_page.dart';
import '../ui/pages/eporner/eporner_detail_page.dart';
import '../ui/pages/exhentai/exhentai_detail_page.dart';
import '../ui/pages/galleryepic/galleryepic_detail_page.dart';
import '../ui/pages/hanime1/hanime1_detail_page.dart';
import '../ui/pages/hqporner/hqporner_detail_page.dart';
import '../ui/pages/iwara/iwara_detail_page.dart';
import '../ui/pages/kuraa/kuraa_detail_page.dart';
import '../ui/pages/misskon/misskon_detail_page.dart';
import '../ui/pages/mzt/mzt_detail_page.dart';
import '../ui/pages/nucosplay/nucosplay_detail_page.dart';
import '../ui/pages/pinse/pinse_detail_page.dart';
import '../ui/pages/pixibb/pixibb_detail_page.dart';
import '../ui/pages/pornbox/pornbox_detail_page.dart';
import '../ui/pages/pornhub/pornhub_detail_page.dart';
import '../ui/pages/rule34video/rule34video_detail_page.dart';
import '../ui/pages/spankbang/spankbang_detail_page.dart';
import '../ui/pages/video/video_detail_page.dart';
import '../ui/pages/xvideos/xvideos_detail_page.dart';
import '../ui/pages/cosxplay/cosxplay_detail_page.dart';
import '../ui/pages/cosplayporntube/cosplayporntube_detail_page.dart';
import '../ui/pages/xhamster/xhamster_detail_page.dart';
import '../ui/pages/xnxx/xnxx_detail_page.dart';
import '../ui/pages/nsfwpub/nsfwpub_detail_page.dart';
import '../ui/pages/thothub/thothub_detail_page.dart';
import '../ui/pages/njav/njav_detail_page.dart';
import '../ui/pages/vjav/vjav_detail_page.dart';
import '../ui/pages/javguru/javguru_detail_page.dart';
import '../ui/pages/av123/av123_detail_page.dart';
import '../ui/pages/javmost/javmost_detail_page.dart';

enum VideoSiteType {
  hcVideo('HC影视'),
  hanime1('Hanime1'),
  iwara('Iwara'),
  rule34video('Rule34Video'),
  pinse('91品色'),
  pornbox('PornBox'),
  eporner('EPorner'),
  hqporner('HQPorner'),
  spankbang('SpankBang'),
  pornhub('Pornhub'),
  xvideos('XVideos'),
  cosxplay('CosXPlay'),
  cosplayporntube('CosplayPornTube'),
  xhamster('xHamster'),
  xnxx('XNXX'),
  thothub('Thothub'),
  njav('NJAV'),
  vjav('VJAV'),
  javguru('JavGuru'),
  av123('123AV'),
  javmost('JavMost');

  final String label;
  const VideoSiteType(this.label);
}

class RandomDiscoveryService {
  static final Random _rng = Random();

  /// Launch a random album from the given website catalog
  static Future<void> openRandomAlbum(
    BuildContext context,
    MediaSourceType source, {
    bool replace = false,
  }) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 正在从【${source.label}】全库随机抽取...'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      switch (source) {
        case MediaSourceType.hc:
          final randomPage = _rng.nextInt(1200) + 1;
          final res = await HCApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, AlbumDetailPage(initialItem: item), replace);
            return;
          }
          break;

        case MediaSourceType.exhentai:
          final randomPage = _rng.nextInt(250) + 1;
          final res = await ExHentaiApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, ExDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.mzt:
          final randomPage = _rng.nextInt(60) + 1;
          final res = await MztApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, MztDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.misskon:
          final randomPage = _rng.nextInt(200) + 1;
          final res = await MisskonApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, MisskonDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.pixibb:
          final randomPage = _rng.nextInt(60) + 1;
          final res = await PixibbApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, PixibbDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.cosplaytele:
          final randomPage = _rng.nextInt(60) + 1;
          final res = await CosplayteleApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, CosplayteleDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.nucosplay:
          final randomPage = _rng.nextInt(60) + 1;
          final res = await NucosplayApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, NucosplayDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.cosvault:
          final randomPage = _rng.nextInt(90) + 1;
          final res = await CosvaultApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, CosvaultDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.galleryepic:
          final randomPage = _rng.nextInt(150) + 1;
          final res = await GalleryepicApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, GalleryepicDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.coomer:
          final randomOffset = _rng.nextInt(2000);
          final res = await CoomerApiService.fetchRecentPosts(offset: randomOffset);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, CoomerDetailPage(item: item), replace);
            return;
          }
          break;

        case MediaSourceType.kuraa:
          final catChoice = _rng.nextInt(3);
          if (catChoice == 0) {
            // 1. 秀人 (storageLocationId: '2', parentId: '11', ~2060 folders)
            final randomOffset = _rng.nextInt(2000);
            final res = await KuraaApiService.fetchFiles(
              storageLocationId: '2',
              parentId: '11',
              offset: randomOffset,
              limit: 10,
            );
            final folders = res.items.where((f) => f.isFolder).toList();
            if (folders.isNotEmpty) {
              final folder = folders[_rng.nextInt(folders.length)];
              if (!context.mounted) return;
              _navigateTo(context, KuraaDetailPage(folderItem: folder), replace);
              return;
            }
          } else if (catChoice == 1) {
            // 2. 达盖尔 (storageLocationId: '4', parentId: '36009', ~7790 folders)
            final token = await KuraaApiService.unlockStorageLocation(
              '4',
              KuraaApiService.defaultInnerPassword,
            );
            final randomOffset = _rng.nextInt(7700);
            final res = await KuraaApiService.fetchFiles(
              storageLocationId: '4',
              parentId: '36009',
              offset: randomOffset,
              limit: 10,
              token: token,
            );
            final folders = res.items.where((f) => f.isFolder).toList();
            if (folders.isNotEmpty) {
              final folder = folders[_rng.nextInt(folders.length)];
              if (!context.mounted) return;
              _navigateTo(context, KuraaDetailPage(folderItem: folder, token: token), replace);
              return;
            }
          } else {
            // 3. 二次元 (storageLocationId: '2', parentId: '32407', ~26700 images)
            final randomOffset = _rng.nextInt(26700);
            final res = await KuraaApiService.fetchFiles(
              storageLocationId: '2',
              parentId: '32407',
              offset: randomOffset,
              limit: 50,
            );
            final images = res.items.where((f) => f.isImage).toList();
            if (images.isNotEmpty) {
              final imageUrls = images.map((img) => img.downloadUrl).toList();
              final previewUrls = images
                  .map((img) => img.previewUrl.isNotEmpty
                      ? img.previewUrl
                      : (img.thumbnailUrl.isNotEmpty ? img.thumbnailUrl : img.downloadUrl))
                  .toList();
              final coverUrl = images.first.thumbnailUrl.isNotEmpty
                  ? images.first.thumbnailUrl
                  : images.first.previewUrl;

              final pseudoFolder = KuraaFileItem(
                id: '32407',
                storageLocationId: '2',
                name: '二次元精选插画 (随机第 ${(randomOffset / 50).floor() + 1} 组)',
                type: 'folder',
                size: 0,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
                hasThumbnail: true,
                tags: ['二次元', '动漫', '插画'],
              );

              final album = AlbumItem(
                title: pseudoFolder.name,
                slug: 'kuraa_2d_$randomOffset',
                detailUrl: 'https://p.kuraa.cc/?storageLocationId=2&folderId=32407&offset=$randomOffset',
                coverUrl: coverUrl,
                date: DateTime.now().toString().split(' ').first,
                author: 'Kuraa',
                tags: ['Kuraa', '二次元', '插画'],
                sourceType: MediaSourceType.kuraa,
                imageUrls: imageUrls,
                previewUrls: previewUrls,
                isDetailLoaded: true,
              );

              if (!context.mounted) return;
              _navigateTo(
                context,
                KuraaDetailPage(folderItem: pseudoFolder, initialAlbum: album),
                replace,
              );
              return;
            }
          }
          break;

        case MediaSourceType.nsfwpub:
          final randomPage = _rng.nextInt(30) + 1;
          final res = await NsfwpubApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, NsfwpubDetailPage(item: item), replace);
            return;
          }
          break;
      }
    } catch (e) {
      debugPrint('[RandomDiscoveryService] Error loading random album: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎲 随机抽取失败，请稍后重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Launch a random video from the given website catalog
  static Future<void> openRandomVideo(
    BuildContext context,
    VideoSiteType site, {
    bool replace = false,
  }) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 正在从【${site.label}】全库随机抽取...'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      switch (site) {
        case VideoSiteType.hcVideo:
          final randomPage = _rng.nextInt(80) + 1;
          final res = await VideoApiService.fetchVideoPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, VideoDetailPage(initialItem: item), replace);
            return;
          }
          break;

        case VideoSiteType.hanime1:
          final randomPage = _rng.nextInt(120) + 1;
          final res = await Hanime1ApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, Hanime1DetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.iwara:
          final randomPage = _rng.nextInt(100) + 1;
          final res = await IwaraApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, IwaraDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.rule34video:
          final randomPage = _rng.nextInt(100) + 1;
          final res = await Rule34VideoApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, Rule34VideoDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.pinse:
          final randomPage = _rng.nextInt(40) + 1;
          final res = await PinseApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, PinseDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.pornbox:
          final randomPage = _rng.nextInt(80) + 1;
          final res = await PornboxApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, PornboxDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.eporner:
          final randomPage = _rng.nextInt(150) + 1;
          final res = await EpornerApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, EpornerDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.hqporner:
          final randomPage = _rng.nextInt(150) + 1;
          final res = await HqpornerApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, HqpornerDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.spankbang:
          final randomPage = _rng.nextInt(80) + 1;
          final res = await SpankbangApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, SpankbangDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.pornhub:
          final randomPage = _rng.nextInt(80) + 1;
          final res = await PornhubApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, PornhubDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.xvideos:
          final randomPage = _rng.nextInt(80) + 1;
          final res = await XVideosApiService.fetchPageData(page: randomPage);
          if (res != null && res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, XVideosDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.cosxplay:
          final randomPage = _rng.nextInt(100) + 1;
          final res = await CosxplayApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, CosxplayDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.cosplayporntube:
          final randomPage = _rng.nextInt(100) + 1;
          final res = await CosplayporntubeApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, CosplayporntubeDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.xhamster:
          final randomPage = _rng.nextInt(50) + 1;
          final res = await XhamsterApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, XhamsterDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.xnxx:
          final randomPage = _rng.nextInt(50) + 1;
          final res = await XnxxApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, XnxxDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.thothub:
          final randomPage = _rng.nextInt(50) + 1;
          final res = await ThothubApiService.fetchPageData(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, ThothubDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.njav:
          final randomPage = _rng.nextInt(20) + 1;
          final res = await NjavApiService.fetchVideos(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, NjavDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.vjav:
          final randomPage = _rng.nextInt(20) + 1;
          final res = await VjavApiService.fetchVideos(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, VjavDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.javguru:
          final randomPage = _rng.nextInt(20) + 1;
          final res = await JavguruApiService.fetchVideos(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, JavguruDetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.av123:
          final randomPage = _rng.nextInt(20) + 1;
          final res = await Av123ApiService.fetchVideos(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, Av123DetailPage(item: item), replace);
            return;
          }
          break;

        case VideoSiteType.javmost:
          final randomPage = _rng.nextInt(20) + 1;
          final res = await JavmostApiService.fetchVideos(page: randomPage);
          if (res.items.isNotEmpty) {
            final item = res.items[_rng.nextInt(res.items.length)];
            if (!context.mounted) return;
            _navigateTo(context, JavmostDetailPage(item: item), replace);
            return;
          }
          break;
      }
    } catch (e) {
      debugPrint('[RandomDiscoveryService] Error loading random video: $e');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎲 随机抽取失败，请稍后重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  static void _navigateTo(BuildContext context, Widget page, bool replace) {
    if (!context.mounted) return;
    if (replace) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }
}
