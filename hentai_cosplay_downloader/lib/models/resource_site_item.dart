import 'package:flutter/cupertino.dart';
import '../ui/pages/browse/browse_page.dart';
import '../ui/pages/coomer/coomer_browse_page.dart';
import '../ui/pages/cosplaytele/cosplaytele_browse_page.dart';
import '../ui/pages/eporner/eporner_browse_page.dart';
import '../ui/pages/exhentai/exhentai_browse_page.dart';
import '../ui/pages/hanime1/hanime1_browse_page.dart';
import '../ui/pages/hqporner/hqporner_browse_page.dart';
import '../ui/pages/kuraa/kuraa_browse_page.dart';
import '../ui/pages/misskon/misskon_browse_page.dart';
import '../ui/pages/mzt/mzt_browse_page.dart';
import '../ui/pages/nucosplay/nucosplay_browse_page.dart';
import '../ui/pages/pinse/pinse_browse_page.dart';
import '../ui/pages/pixibb/pixibb_browse_page.dart';
import '../ui/pages/pornbox/pornbox_browse_page.dart';
import '../ui/pages/pornhub/pornhub_browse_page.dart';
import '../ui/pages/spankbang/spankbang_browse_page.dart';
import '../ui/pages/twitter_rankings/twitter_browse_page.dart';
import '../ui/pages/video/video_browse_page.dart';
import '../ui/theme/ios_theme.dart';

class ResourceSiteItem {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Widget widget;

  const ResourceSiteItem({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.widget,
  });
}

class ResourceSiteRegistry {
  static const List<String> defaultOrder = [
    'hc_gallery',
    'hc_video',
    'mzt',
    'misskon',
    'coomer',
    'pinse',
    'pornbox',
    'kuraa',
    'twitter',
    'exhentai',
    'pixibb',
    'cosplaytele',
    'nucosplay',
    'hanime1',
    'eporner',
    'hqporner',
    'spankbang',
    'pornhub',
  ];

  static final Map<String, ResourceSiteItem> allSites = {
    'hc_gallery': const ResourceSiteItem(
      key: 'hc_gallery',
      label: 'HC 图集',
      description: 'Hentai Cosplay 高清原站图集',
      icon: CupertinoIcons.photo_on_rectangle,
      color: IosTheme.primaryPink,
      widget: BrowsePage(),
    ),
    'hc_video': const ResourceSiteItem(
      key: 'hc_video',
      label: 'HC 视频',
      description: 'Hentai Cosplay 在线视频专区',
      icon: CupertinoIcons.play_rectangle_fill,
      color: Color(0xFFFF5252),
      widget: VideoBrowsePage(),
    ),
    'mzt': const ResourceSiteItem(
      key: 'mzt',
      label: '妹子图',
      description: '妹子图写真与自拍图库',
      icon: CupertinoIcons.sparkles,
      color: Color(0xFFFF4081),
      widget: MztBrowsePage(),
    ),
    'misskon': const ResourceSiteItem(
      key: 'misskon',
      label: 'MissKon',
      description: 'MissKon 日韩超清写真套图',
      icon: CupertinoIcons.camera_fill,
      color: Color(0xFFE74C3C),
      widget: MisskonBrowsePage(),
    ),
    'coomer': const ResourceSiteItem(
      key: 'coomer',
      label: 'Coomer',
      description: 'Coomer 创作者付费内容社区',
      icon: CupertinoIcons.person_2_fill,
      color: Color(0xFF00AFF0),
      widget: CoomerBrowsePage(),
    ),
    'pinse': const ResourceSiteItem(
      key: 'pinse',
      label: '91品色',
      description: '91品色 原创自拍影视',
      icon: CupertinoIcons.flame_fill,
      color: Color(0xFFFF8C00),
      widget: PinseBrowsePage(),
    ),
    'pornbox': const ResourceSiteItem(
      key: 'pornbox',
      label: 'PornBox',
      description: 'PornBox 欧美影视专区',
      icon: CupertinoIcons.cube_box_fill,
      color: Color(0xFF8E24AA),
      widget: PornboxBrowsePage(),
    ),
    'kuraa': const ResourceSiteItem(
      key: 'kuraa',
      label: 'Kuraa',
      description: 'Kuraa 优质云盘图库',
      icon: CupertinoIcons.cloud_fill,
      color: Color(0xFF00897B),
      widget: KuraaBrowsePage(),
    ),
    'twitter': const ResourceSiteItem(
      key: 'twitter',
      label: 'Twitter 榜',
      description: 'Twitter / TikTok 热门推特视频',
      icon: CupertinoIcons.chat_bubble_2_fill,
      color: Color(0xFF1D9BF0),
      widget: TwitterBrowsePage(),
    ),
    'exhentai': const ResourceSiteItem(
      key: 'exhentai',
      label: 'ExHentai',
      description: 'ExHentai / E-Hentai 经典同人画廊',
      icon: CupertinoIcons.book_fill,
      color: Color(0xFF9C27B0),
      widget: ExHentaiBrowsePage(),
    ),
    'pixibb': const ResourceSiteItem(
      key: 'pixibb',
      label: 'PixiBB',
      description: 'PixiBB 4K 原图写真展',
      icon: CupertinoIcons.heart_fill,
      color: Color(0xFFFF4081),
      widget: PixibbBrowsePage(),
    ),
    'cosplaytele': const ResourceSiteItem(
      key: 'cosplaytele',
      label: 'CosplayTele',
      description: 'CosplayTele 电报频道合集',
      icon: CupertinoIcons.paperplane_fill,
      color: Color(0xFF0088CC),
      widget: CosplayteleBrowsePage(),
    ),
    'nucosplay': const ResourceSiteItem(
      key: 'nucosplay',
      label: 'NuCosplay',
      description: 'NuCosplay 精选 Coser 写真',
      icon: CupertinoIcons.star_circle_fill,
      color: Color(0xFFAB47BC),
      widget: NucosplayBrowsePage(),
    ),
    'hanime1': const ResourceSiteItem(
      key: 'hanime1',
      label: 'Hanime1',
      description: 'Hanime1 动漫里番影视',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF2E63),
      widget: Hanime1BrowsePage(),
    ),
    'eporner': const ResourceSiteItem(
      key: 'eporner',
      label: 'EPorner',
      description: 'EPorner 4K / VR 影视精选',
      icon: CupertinoIcons.tv_fill,
      color: Color(0xFFE53935),
      widget: EpornerBrowsePage(),
    ),
    'hqporner': const ResourceSiteItem(
      key: 'hqporner',
      label: 'HQPorner',
      description: 'HQPorner 1080P 超清影视',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF9800),
      widget: HqpornerBrowsePage(),
    ),
    'spankbang': const ResourceSiteItem(
      key: 'spankbang',
      label: 'SpankBang',
      description: 'SpankBang 极速影视流',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFF2196F3),
      widget: SpankbangBrowsePage(),
    ),
    'pornhub': const ResourceSiteItem(
      key: 'pornhub',
      label: 'Pornhub',
      description: 'Pornhub 官方精选视频',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFFFF9900),
      widget: PornhubBrowsePage(),
    ),
  };

  static List<ResourceSiteItem> getOrderedSites(List<String>? orderKeys) {
    final effectiveKeys = (orderKeys != null && orderKeys.isNotEmpty)
        ? List<String>.from(orderKeys)
        : List<String>.from(defaultOrder);

    // Ensure any newly added site keys are present
    for (final k in defaultOrder) {
      if (!effectiveKeys.contains(k)) {
        effectiveKeys.add(k);
      }
    }

    final List<ResourceSiteItem> result = [];
    for (final k in effectiveKeys) {
      final site = allSites[k];
      if (site != null) {
        result.add(site);
      }
    }
    return result;
  }
}
