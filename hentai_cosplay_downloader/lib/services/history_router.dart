import 'package:flutter/cupertino.dart';
import '../models/album_item.dart';
import '../models/browsing_history_record.dart';
import '../models/video_item.dart';
import '../services/kuraa/kuraa_api_service.dart';
import '../ui/pages/browse/album_detail_page.dart';
import '../ui/pages/coomer/coomer_detail_page.dart';
import '../ui/pages/cosplaytele/cosplaytele_detail_page.dart';
import '../ui/pages/eporner/eporner_detail_page.dart';
import '../ui/pages/exhentai/exhentai_detail_page.dart';
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

class HistoryRouter {
  static void openRecord(BuildContext context, BrowsingHistoryRecord record) {
    final albumItem = AlbumItem(
      title: record.title,
      slug: record.id,
      detailUrl: record.detailUrl,
      coverUrl: record.coverUrl,
      date: '',
      author: record.author,
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
    );

    Widget? targetPage;

    switch (record.siteKey) {
      case 'hc_gallery':
        targetPage = AlbumDetailPage(initialItem: albumItem);
        break;
      case 'hc_video':
        targetPage = VideoDetailPage(initialItem: videoItem);
        break;
      case 'mzt':
        targetPage = MztDetailPage(item: albumItem);
        break;
      case 'misskon':
        targetPage = MisskonDetailPage(item: albumItem);
        break;
      case 'coomer':
        targetPage = CoomerDetailPage(item: albumItem);
        break;
      case 'pinse':
        targetPage = PinseDetailPage(item: videoItem);
        break;
      case 'pornbox':
        targetPage = PornboxDetailPage(item: videoItem);
        break;
      case 'kuraa':
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
        targetPage = KuraaDetailPage(folderItem: pseudoFolder, initialAlbum: albumItem);
        break;
      case 'twitter':
        if (record.videoUrl != null && record.videoUrl!.isNotEmpty) {
          VideoPlayerPage.openRemote(
            context,
            url: record.videoUrl!,
            title: record.title,
            author: record.author,
            webPlayerUrl: record.detailUrl,
          );
          return;
        } else {
          targetPage = VideoDetailPage(initialItem: videoItem);
        }
        break;
      case 'exhentai':
        targetPage = ExDetailPage(item: albumItem);
        break;
      case 'pixibb':
        targetPage = PixibbDetailPage(item: albumItem);
        break;
      case 'cosplaytele':
        targetPage = CosplayteleDetailPage(item: albumItem);
        break;
      case 'nucosplay':
        targetPage = NucosplayDetailPage(item: albumItem);
        break;
      case 'hanime1':
        targetPage = Hanime1DetailPage(item: videoItem);
        break;
      case 'iwara':
        targetPage = IwaraDetailPage(item: videoItem);
        break;
      case 'rule34video':
        targetPage = Rule34VideoDetailPage(item: videoItem);
        break;
      case 'eporner':
        targetPage = EpornerDetailPage(item: videoItem);
        break;
      case 'hqporner':
        targetPage = HqpornerDetailPage(item: videoItem);
        break;
      case 'spankbang':
        targetPage = SpankbangDetailPage(item: videoItem);
        break;
      case 'pornhub':
        targetPage = PornhubDetailPage(item: videoItem);
        break;
      case 'jable':
        WebVideoPlayerPage.open(context, url: record.detailUrl, title: record.title);
        return;
      default:
        if (record.isVideo) {
          targetPage = VideoDetailPage(initialItem: videoItem);
        } else {
          targetPage = AlbumDetailPage(initialItem: albumItem);
        }
    }

    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => targetPage!),
    );
  }
}
