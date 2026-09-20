import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../models/browsing_history_record.dart';
import '../models/video_item.dart';
import '../services/kuraa/kuraa_api_service.dart';
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
import '../ui/pages/video/video_player_page.dart';
import '../ui/pages/video/web_video_player_page.dart';
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

class HistoryRouter {
  static final Map<String, Widget Function(AlbumItem)> _albumRoutes = {
    'hc': (item) => AlbumDetailPage(initialItem: item),
    'hc_gallery': (item) => AlbumDetailPage(initialItem: item),
    'mzt': (item) => MztDetailPage(item: item),
    'misskon': (item) => MisskonDetailPage(item: item),
    'coomer': (item) => CoomerDetailPage(item: item),
    'exhentai': (item) => ExDetailPage(item: item),
    'pixibb': (item) => PixibbDetailPage(item: item),
    'cosplaytele': (item) => CosplayteleDetailPage(item: item),
    'nucosplay': (item) => NucosplayDetailPage(item: item),
    'cosvault': (item) => CosvaultDetailPage(item: item),
    'galleryepic': (item) => GalleryepicDetailPage(item: item),
    'nsfwpub': (item) => NsfwpubDetailPage(item: item),
  };

  static final Map<String, Widget Function(VideoItem)> _videoRoutes = {
    'video': (item) => VideoDetailPage(initialItem: item),
    'hc_video': (item) => VideoDetailPage(initialItem: item),
    'pinse': (item) => PinseDetailPage(item: item),
    'pornbox': (item) => PornboxDetailPage(item: item),
    'hanime1': (item) => Hanime1DetailPage(item: item),
    'iwara': (item) => IwaraDetailPage(item: item),
    'rule34video': (item) => Rule34VideoDetailPage(item: item),
    'eporner': (item) => EpornerDetailPage(item: item),
    'hqporner': (item) => HqpornerDetailPage(item: item),
    'spankbang': (item) => SpankbangDetailPage(item: item),
    'pornhub': (item) => PornhubDetailPage(item: item),
    'xvideos': (item) => XVideosDetailPage(item: item),
    'cosxplay': (item) => CosxplayDetailPage(item: item),
    'cosplayporntube': (item) => CosplayporntubeDetailPage(item: item),
    'xhamster': (item) => XhamsterDetailPage(item: item),
    'xnxx': (item) => XnxxDetailPage(item: item),
    'thothub': (item) => ThothubDetailPage(item: item),
    'njav': (item) => NjavDetailPage(item: item),
    'vjav': (item) => VjavDetailPage(item: item),
    'javguru': (item) => JavguruDetailPage(item: item),
    'av123': (item) => Av123DetailPage(item: item),
    'javmost': (item) => JavmostDetailPage(item: item),
    'memojav': (item) => MemojavDetailPage(item: item),
    'hohoj': (item) => HohojDetailPage(item: item),
  };

  static void openRecord(BuildContext context, BrowsingHistoryRecord record) {
    MediaSourceType parsedSource = MediaSourceType.hc;
    if (record.extra != null && record.extra!['sourceType'] != null) {
      try {
        parsedSource = MediaSourceType.values.byName(record.extra!['sourceType'].toString());
      } catch (_) {}
    } else {
      try {
        parsedSource = MediaSourceType.values.byName(record.siteKey);
      } catch (_) {}
    }

    final albumItem = AlbumItem(
      title: record.title,
      slug: record.id,
      detailUrl: record.detailUrl,
      coverUrl: record.coverUrl,
      date: '',
      author: record.author,
      sourceType: parsedSource,
      rawData: record.extra ?? {},
    );

    final videoItem = VideoItem(
      title: record.title,
      slug: record.id,
      detailUrl: record.detailUrl,
      coverUrl: record.coverUrl,
      duration: record.duration ?? '',
      date: '',
      author: record.author,
      videoUrl: record.videoUrl,
      rawData: record.extra ?? {},
    );

    // 1. Web video players
    if (const {'jable', 'missav', 'supjav'}.contains(record.siteKey)) {
      WebVideoPlayerPage.open(context, url: record.detailUrl, title: record.title);
      return;
    }

    // 2. Twitter specific playback
    if (record.siteKey == 'twitter') {
      if (record.videoUrl != null && record.videoUrl!.isNotEmpty) {
        VideoPlayerPage.openRemote(
          context,
          url: record.videoUrl!,
          title: record.title,
          author: record.author,
          webPlayerUrl: record.detailUrl,
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoDetailPage(initialItem: videoItem)),
      );
      return;
    }

    // 3. Kuraa folder structure
    if (record.siteKey == 'kuraa') {
      final pseudoFolder = KuraaFileItem(
        id: record.extra?['folderId'] ?? '',
        storageLocationId: '',
        name: record.title,
        type: 'folder',
        size: 0,
        createdAt: '',
        updatedAt: '',
        hasThumbnail: false,
        tags: const [],
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => KuraaDetailPage(folderItem: pseudoFolder, initialAlbum: albumItem)),
      );
      return;
    }

    // 4. Mapped routes
    final albumBuilder = _albumRoutes[record.siteKey];
    if (albumBuilder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => albumBuilder(albumItem)),
      );
      return;
    }

    final videoBuilder = _videoRoutes[record.siteKey];
    if (videoBuilder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => videoBuilder(videoItem)),
      );
      return;
    }

    // 5. Default fallback
    final targetPage = record.isVideo
        ? VideoDetailPage(initialItem: videoItem)
        : AlbumDetailPage(initialItem: albumItem);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }
}
