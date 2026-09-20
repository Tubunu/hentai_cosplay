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
import 'memojav/memojav_api_service.dart';
import 'hohoj/hohoj_api_service.dart';
import 'app_logger.dart';

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
import '../ui/pages/memojav/memojav_detail_page.dart';
import '../ui/pages/hohoj/hohoj_detail_page.dart';

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
  javmost('JavMost'),
  memojav('MemoJAV'),
  hohoj('HoHoJ');

  final String label;
  const VideoSiteType(this.label);
}

class RandomDiscoveryService {
  static final Random _rng = Random();

  static bool _isExploring = false;

  static final Map<MediaSourceType, Future<Widget?> Function(Random rng)> _albumHandlers = {
    MediaSourceType.hc: (rng) async {
      final res = await HCApiService.fetchPageData(page: rng.nextInt(1200) + 1);
      if (res != null && res.items.isNotEmpty) {
        return AlbumDetailPage(initialItem: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.exhentai: (rng) async {
      final res = await ExHentaiApiService.fetchPageData(page: rng.nextInt(250) + 1);
      if (res != null && res.items.isNotEmpty) {
        return ExDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.mzt: (rng) async {
      final res = await MztApiService.fetchPageData(page: rng.nextInt(60) + 1);
      if (res != null && res.items.isNotEmpty) {
        return MztDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.misskon: (rng) async {
      final res = await MisskonApiService.fetchPageData(page: rng.nextInt(200) + 1);
      if (res != null && res.items.isNotEmpty) {
        return MisskonDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.pixibb: (rng) async {
      final res = await PixibbApiService.fetchPageData(page: rng.nextInt(60) + 1);
      if (res != null && res.items.isNotEmpty) {
        return PixibbDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.cosplaytele: (rng) async {
      final res = await CosplayteleApiService.fetchPageData(page: rng.nextInt(60) + 1);
      if (res != null && res.items.isNotEmpty) {
        return CosplayteleDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.nucosplay: (rng) async {
      final res = await NucosplayApiService.fetchPageData(page: rng.nextInt(60) + 1);
      if (res != null && res.items.isNotEmpty) {
        return NucosplayDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.cosvault: (rng) async {
      final res = await CosvaultApiService.fetchPageData(page: rng.nextInt(90) + 1);
      if (res != null && res.items.isNotEmpty) {
        return CosvaultDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.galleryepic: (rng) async {
      final res = await GalleryepicApiService.fetchPageData(page: rng.nextInt(150) + 1);
      if (res != null && res.items.isNotEmpty) {
        return GalleryepicDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.coomer: (rng) async {
      final res = await CoomerApiService.fetchRecentPosts(offset: rng.nextInt(2000));
      if (res != null && res.items.isNotEmpty) {
        return CoomerDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    MediaSourceType.kuraa: (rng) async {
      final catChoice = rng.nextInt(3);
      if (catChoice == 0) {
        // 1. 秀人 (storageLocationId: '2', parentId: '11', ~2060 folders)
        final randomOffset = rng.nextInt(2000);
        final res = await KuraaApiService.fetchFiles(
          storageLocationId: '2',
          parentId: '11',
          offset: randomOffset,
          limit: 10,
        );
        final folders = res.items.where((f) => f.isFolder).toList();
        if (folders.isNotEmpty) {
          final folder = folders[rng.nextInt(folders.length)];
          return KuraaDetailPage(folderItem: folder);
        }
      } else if (catChoice == 1) {
        // 2. 达盖尔 (storageLocationId: '4', parentId: '36009', ~7790 folders)
        final token = await KuraaApiService.unlockStorageLocation(
          '4',
          KuraaApiService.defaultInnerPassword,
        );
        final randomOffset = rng.nextInt(7700);
        final res = await KuraaApiService.fetchFiles(
          storageLocationId: '4',
          parentId: '36009',
          offset: randomOffset,
          limit: 10,
          token: token,
        );
        final folders = res.items.where((f) => f.isFolder).toList();
        if (folders.isNotEmpty) {
          final folder = folders[rng.nextInt(folders.length)];
          return KuraaDetailPage(folderItem: folder, token: token);
        }
      } else {
        // 3. 二次元 (storageLocationId: '2', parentId: '32407', ~26700 images)
        final randomOffset = rng.nextInt(26700);
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

          return KuraaDetailPage(folderItem: pseudoFolder, initialAlbum: album);
        }
      }
      return null;
    },
    MediaSourceType.nsfwpub: (rng) async {
      final res = await NsfwpubApiService.fetchPageData(page: rng.nextInt(30) + 1);
      if (res.items.isNotEmpty) {
        return NsfwpubDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
  };

  static final Map<VideoSiteType, Future<Widget?> Function(Random rng)> _videoHandlers = {
    VideoSiteType.hcVideo: (rng) async {
      final res = await VideoApiService.fetchVideoPageData(page: rng.nextInt(80) + 1);
      if (res != null && res.items.isNotEmpty) {
        return VideoDetailPage(initialItem: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.hanime1: (rng) async {
      final res = await Hanime1ApiService.fetchPageData(page: rng.nextInt(120) + 1);
      if (res != null && res.items.isNotEmpty) {
        return Hanime1DetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.iwara: (rng) async {
      final res = await IwaraApiService.fetchPageData(page: rng.nextInt(100) + 1);
      if (res.items.isNotEmpty) {
        return IwaraDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.rule34video: (rng) async {
      final res = await Rule34VideoApiService.fetchPageData(page: rng.nextInt(100) + 1);
      if (res.items.isNotEmpty) {
        return Rule34VideoDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.pinse: (rng) async {
      final res = await PinseApiService.fetchPageData(page: rng.nextInt(40) + 1);
      if (res != null && res.items.isNotEmpty) {
        return PinseDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.pornbox: (rng) async {
      final res = await PornboxApiService.fetchPageData(page: rng.nextInt(80) + 1);
      if (res != null && res.items.isNotEmpty) {
        return PornboxDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.eporner: (rng) async {
      final res = await EpornerApiService.fetchPageData(page: rng.nextInt(150) + 1);
      if (res != null && res.items.isNotEmpty) {
        return EpornerDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.hqporner: (rng) async {
      final res = await HqpornerApiService.fetchPageData(page: rng.nextInt(150) + 1);
      if (res != null && res.items.isNotEmpty) {
        return HqpornerDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.spankbang: (rng) async {
      final res = await SpankbangApiService.fetchPageData(page: rng.nextInt(80) + 1);
      if (res != null && res.items.isNotEmpty) {
        return SpankbangDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.pornhub: (rng) async {
      final res = await PornhubApiService.fetchPageData(page: rng.nextInt(80) + 1);
      if (res != null && res.items.isNotEmpty) {
        return PornhubDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.xvideos: (rng) async {
      final res = await XVideosApiService.fetchPageData(page: rng.nextInt(80) + 1);
      if (res != null && res.items.isNotEmpty) {
        return XVideosDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.cosxplay: (rng) async {
      final res = await CosxplayApiService.fetchPageData(page: rng.nextInt(100) + 1);
      if (res.items.isNotEmpty) {
        return CosxplayDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.cosplayporntube: (rng) async {
      final res = await CosplayporntubeApiService.fetchPageData(page: rng.nextInt(100) + 1);
      if (res.items.isNotEmpty) {
        return CosplayporntubeDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.xhamster: (rng) async {
      final res = await XhamsterApiService.fetchPageData(page: rng.nextInt(50) + 1);
      if (res.items.isNotEmpty) {
        return XhamsterDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.xnxx: (rng) async {
      final res = await XnxxApiService.fetchPageData(page: rng.nextInt(50) + 1);
      if (res.items.isNotEmpty) {
        return XnxxDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.thothub: (rng) async {
      final res = await ThothubApiService.fetchPageData(page: rng.nextInt(50) + 1);
      if (res.items.isNotEmpty) {
        return ThothubDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.njav: (rng) async {
      final res = await NjavApiService.fetchVideos(page: rng.nextInt(20) + 1);
      if (res.items.isNotEmpty) {
        return NjavDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.vjav: (rng) async {
      final res = await VjavApiService.fetchVideos(page: rng.nextInt(20) + 1);
      if (res.items.isNotEmpty) {
        return VjavDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.javguru: (rng) async {
      final res = await JavguruApiService.fetchVideos(page: rng.nextInt(20) + 1);
      if (res.items.isNotEmpty) {
        return JavguruDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.av123: (rng) async {
      final res = await Av123ApiService.fetchVideos(page: rng.nextInt(20) + 1);
      if (res.items.isNotEmpty) {
        return Av123DetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.javmost: (rng) async {
      final res = await JavmostApiService.fetchVideos(page: rng.nextInt(20) + 1);
      if (res.items.isNotEmpty) {
        return JavmostDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.memojav: (rng) async {
      final res = await MemojavApiService.fetchVideos(page: rng.nextInt(20) + 1);
      if (res.items.isNotEmpty) {
        return MemojavDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
    VideoSiteType.hohoj: (rng) async {
      final res = await HohojApiService.fetchVideos(page: rng.nextInt(50) + 1);
      if (res.items.isNotEmpty) {
        return HohojDetailPage(item: res.items[rng.nextInt(res.items.length)]);
      }
      return null;
    },
  };

  /// Launch a random album from the given website catalog
  static Future<void> openRandomAlbum(
    BuildContext context,
    MediaSourceType source, {
    bool replace = false,
  }) async {
    if (_isExploring) return;
    _isExploring = true;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 正在从【${source.label}】全库随机抽取...'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final handler = _albumHandlers[source];
      if (handler != null) {
        final page = await handler(_rng);
        if (page != null && context.mounted) {
          _navigateTo(context, page, replace);
          return;
        }
      }
    } catch (e, st) {
      AppLogger.e('RandomDiscoveryService', 'Error loading random album: $e', e, st);
    } finally {
      _isExploring = false;
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
    if (_isExploring) return;
    _isExploring = true;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 正在从【${site.label}】全库随机抽取...'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final handler = _videoHandlers[site];
      if (handler != null) {
        final page = await handler(_rng);
        if (page != null && context.mounted) {
          _navigateTo(context, page, replace);
          return;
        }
      }
    } catch (e, st) {
      AppLogger.e('RandomDiscoveryService', 'Error loading random video: $e', e, st);
    } finally {
      _isExploring = false;
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
