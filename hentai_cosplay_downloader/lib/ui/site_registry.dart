import 'package:flutter/cupertino.dart';
import '../models/resource_site_item.dart';
import 'pages/browse/browse_page.dart';
import 'pages/coomer/coomer_browse_page.dart';
import 'pages/cosplaytele/cosplaytele_browse_page.dart';
import 'pages/cosvault/cosvault_browse_page.dart';
import 'pages/eporner/eporner_browse_page.dart';
import 'pages/exhentai/exhentai_browse_page.dart';
import 'pages/galleryepic/galleryepic_browse_page.dart';
import 'pages/hanime1/hanime1_browse_page.dart';
import 'pages/hqporner/hqporner_browse_page.dart';
import 'pages/iwara/iwara_browse_page.dart';
import 'pages/jable/jable_browse_page.dart';
import 'pages/kuraa/kuraa_browse_page.dart';
import 'pages/misskon/misskon_browse_page.dart';
import 'pages/mzt/mzt_browse_page.dart';
import 'pages/nucosplay/nucosplay_browse_page.dart';
import 'pages/pinse/pinse_browse_page.dart';
import 'pages/pixibb/pixibb_browse_page.dart';
import 'pages/pornbox/pornbox_browse_page.dart';
import 'pages/pornhub/pornhub_browse_page.dart';
import 'pages/rule34video/rule34video_browse_page.dart';
import 'pages/spankbang/spankbang_browse_page.dart';
import 'pages/twitter_rankings/twitter_browse_page.dart';
import 'pages/video/video_browse_page.dart';
import 'pages/xvideos/xvideos_browse_page.dart';
import 'pages/cosxplay/cosxplay_browse_page.dart';
import 'pages/cosplayporntube/cosplayporntube_browse_page.dart';
import 'pages/xhamster/xhamster_browse_page.dart';
import 'pages/xnxx/xnxx_browse_page.dart';
import 'pages/nsfwpub/nsfwpub_browse_page.dart';
import 'pages/thothub/thothub_browse_page.dart';
import 'pages/njav/njav_browse_page.dart';
import 'pages/vjav/vjav_browse_page.dart';
import 'pages/javguru/javguru_browse_page.dart';
import 'pages/av123/av123_browse_page.dart';
import 'pages/javmost/javmost_browse_page.dart';
import 'pages/memojav/memojav_browse_page.dart';
import 'pages/hohoj/hohoj_browse_page.dart';
import 'theme/ios_theme.dart';

export '../models/resource_site_item.dart';

typedef SiteWidgetBuilder = Widget Function(BuildContext context);

extension ResourceCategoryUIExtension on ResourceCategory {
  IconData get icon => switch (this) {
        ResourceCategory.gallery => CupertinoIcons.photo_on_rectangle,
        ResourceCategory.jav => CupertinoIcons.tv_fill,
        ResourceCategory.anime => CupertinoIcons.sparkles,
        ResourceCategory.video => CupertinoIcons.play_rectangle_fill,
        ResourceCategory.creator => CupertinoIcons.person_2_fill,
      };

  Color get color => switch (this) {
        ResourceCategory.gallery => const Color(0xFFFF2D55),
        ResourceCategory.jav => const Color(0xFFFF9500),
        ResourceCategory.anime => const Color(0xFFAF52DE),
        ResourceCategory.video => const Color(0xFF007AFF),
        ResourceCategory.creator => const Color(0xFF34C759),
      };
}

class ResourceSiteItem {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final ResourceMediaType mediaType;
  final ResourceCategory category;
  final SiteWidgetBuilder builder;

  const ResourceSiteItem({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.mediaType,
    required this.category,
    required this.builder,
  });
}

class ResourceSiteRegistry {
  static const List<String> defaultImageOrder = [
    'hc_gallery',
    'mzt',
    'misskon',
    'pixibb',
    'cosplaytele',
    'nucosplay',
    'cosvault',
    'galleryepic',
    'kuraa',
    'nsfwpub',
    'exhentai',
  ];

  static const List<String> defaultVideoOrder = [
    'jable',
    'missav',
    'supjav',
    'njav',
    'vjav',
    'javguru',
    'av123',
    'javmost',
    'memojav',
    'hohoj',
    'hanime1',
    'iwara',
    'rule34video',
    'hc_video',
    'pornhub',
    'xvideos',
    'xhamster',
    'xnxx',
    'spankbang',
    'eporner',
    'hqporner',
    'pinse',
    'pornbox',
    'thothub',
    'cosxplay',
    'cosplayporntube',
    'coomer',
    'twitter',
  ];

  static List<String> get defaultOrder => [
        ...defaultImageOrder,
        ...defaultVideoOrder,
      ];

  static final Map<String, ResourceSiteItem> allSites = {
    // ================= 图片专区 (11 站) =================
    'hc_gallery': ResourceSiteItem(
      key: 'hc_gallery',
      label: 'HC 图集',
      description: 'Hentai Cosplay 高清原站图集',
      icon: CupertinoIcons.photo_on_rectangle,
      color: IosTheme.primaryPink,
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: (context) => const BrowsePage(),
    ),
    'mzt': const ResourceSiteItem(
      key: 'mzt',
      label: '妹子图',
      description: '妹子图写真与自拍图库',
      icon: CupertinoIcons.sparkles,
      color: Color(0xFFFF4081),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildMztBrowsePage,
    ),
    'misskon': const ResourceSiteItem(
      key: 'misskon',
      label: 'MissKon',
      description: 'MissKon 日韩超清写真套图',
      icon: CupertinoIcons.camera_fill,
      color: Color(0xFFE74C3C),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildMisskonBrowsePage,
    ),
    'pixibb': const ResourceSiteItem(
      key: 'pixibb',
      label: 'PixiBB',
      description: 'PixiBB 4K 原图写真展',
      icon: CupertinoIcons.heart_fill,
      color: Color(0xFFFF4081),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildPixibbBrowsePage,
    ),
    'cosplaytele': const ResourceSiteItem(
      key: 'cosplaytele',
      label: 'CosplayTele',
      description: 'CosplayTele 电报频道合集',
      icon: CupertinoIcons.paperplane_fill,
      color: Color(0xFF0088CC),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildCosplayteleBrowsePage,
    ),
    'nucosplay': const ResourceSiteItem(
      key: 'nucosplay',
      label: 'NuCosplay',
      description: 'NuCosplay 精选 Coser 写真',
      icon: CupertinoIcons.star_circle_fill,
      color: Color(0xFFAB47BC),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildNucosplayBrowsePage,
    ),
    'cosvault': const ResourceSiteItem(
      key: 'cosvault',
      label: 'CosVault',
      description: 'CosVault 欧美精选同人画廊',
      icon: CupertinoIcons.archivebox_fill,
      color: Color(0xFF3B82F6),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildCosvaultBrowsePage,
    ),
    'galleryepic': const ResourceSiteItem(
      key: 'galleryepic',
      label: 'GalleryEpic',
      description: 'Gallery Epic 高清 Coser 与写真图集',
      icon: CupertinoIcons.photo_fill_on_rectangle_fill,
      color: Color(0xFFE11D48),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildGalleryepicBrowsePage,
    ),
    'kuraa': const ResourceSiteItem(
      key: 'kuraa',
      label: 'Kuraa',
      description: 'Kuraa 优质云盘图库',
      icon: CupertinoIcons.cloud_fill,
      color: Color(0xFF00897B),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildKuraaBrowsePage,
    ),
    'nsfwpub': const ResourceSiteItem(
      key: 'nsfwpub',
      label: 'NSFWPub',
      description: 'NSFWPub 独家Cosplay与模特泄密图集',
      icon: CupertinoIcons.photo_fill_on_rectangle_fill,
      color: Color(0xFFD63384),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildNsfwpubBrowsePage,
    ),
    'exhentai': const ResourceSiteItem(
      key: 'exhentai',
      label: 'ExHentai',
      description: 'ExHentai / E-Hentai 经典同人画廊',
      icon: CupertinoIcons.book_fill,
      color: Color(0xFF9C27B0),
      mediaType: ResourceMediaType.image,
      category: ResourceCategory.gallery,
      builder: _buildExHentaiBrowsePage,
    ),

    // ================= 视频专区 (26 站) =================
    'jable': const ResourceSiteItem(
      key: 'jable',
      label: 'Jable TV',
      description: 'Jable 在线高清日韩视频',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFFFF9900),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildJableBrowsePage,
    ),
    'missav': const ResourceSiteItem(
      key: 'missav',
      label: 'MissAV',
      description: 'MissAV 中文字幕无码高清',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF2D55),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildMissavBrowsePage,
    ),
    'supjav': const ResourceSiteItem(
      key: 'supjav',
      label: 'SupJav',
      description: 'SupJav 极速高清在线播放',
      icon: CupertinoIcons.tv_fill,
      color: Color(0xFF5856D6),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildSupjavBrowsePage,
    ),
    'njav': const ResourceSiteItem(
      key: 'njav',
      label: 'NJAV',
      description: '日本精品 JAV、有码/无码高清影视',
      icon: CupertinoIcons.play_rectangle_fill,
      color: Color(0xFFFE628E),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildNjavBrowsePage,
    ),
    'vjav': const ResourceSiteItem(
      key: 'vjav',
      label: 'VJAV',
      description: '日本热门 JAV 高清极速在线播放',
      icon: CupertinoIcons.tv_fill,
      color: Color(0xFFFF9900),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildVjavBrowsePage,
    ),
    'javguru': const ResourceSiteItem(
      key: 'javguru',
      label: 'JavGuru',
      description: '日本 JAV 热门影片，多线路在线串流与无码精选',
      icon: CupertinoIcons.videocam_circle_fill,
      color: Color(0xFF00ADB5),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildJavguruBrowsePage,
    ),
    'av123': const ResourceSiteItem(
      key: 'av123',
      label: '123AV',
      description: '免费高清 JAV 在线播放，中文界面与无码流出',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFFE50914),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildAv123BrowsePage,
    ),
    'javmost': const ResourceSiteItem(
      key: 'javmost',
      label: 'JavMost',
      description: '日本有码无码 JAV 免费极速在线看',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFA80000),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildJavmostBrowsePage,
    ),
    'memojav': const ResourceSiteItem(
      key: 'memojav',
      label: 'MemoJAV',
      description: 'MemoJAV 高清 JAV 在线观看',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFF6C5CE7),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildMemojavBrowsePage,
    ),
    'hohoj': const ResourceSiteItem(
      key: 'hohoj',
      label: 'HoHoJ',
      description: 'HoHoJ 免费高清日本 AV 在线播放',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFE74C3C),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.jav,
      builder: _buildHohojBrowsePage,
    ),
    'hanime1': const ResourceSiteItem(
      key: 'hanime1',
      label: 'Hanime1',
      description: 'Hanime1 动漫里番影视',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF2E63),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.anime,
      builder: _buildHanime1BrowsePage,
    ),
    'iwara': const ResourceSiteItem(
      key: 'iwara',
      label: 'Iwara',
      description: 'Iwara 3D / MMD 二次元动画',
      icon: CupertinoIcons.play_rectangle_fill,
      color: Color(0xFF00A8FF),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.anime,
      builder: _buildIwaraBrowsePage,
    ),
    'rule34video': const ResourceSiteItem(
      key: 'rule34video',
      label: 'Rule34Video',
      description: 'Rule34Video 3D 二次元动画',
      icon: CupertinoIcons.tv_fill,
      color: Color(0xFFFF6B35),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.anime,
      builder: _buildRule34VideoBrowsePage,
    ),
    'hc_video': const ResourceSiteItem(
      key: 'hc_video',
      label: 'HC 视频',
      description: 'Hentai Cosplay 在线视频专区',
      icon: CupertinoIcons.play_rectangle_fill,
      color: Color(0xFFFF5252),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildVideoBrowsePage,
    ),
    'pornhub': const ResourceSiteItem(
      key: 'pornhub',
      label: 'Pornhub',
      description: 'Pornhub 官方精选视频',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFFFF9900),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildPornhubBrowsePage,
    ),
    'xvideos': const ResourceSiteItem(
      key: 'xvideos',
      label: 'XVideos',
      description: 'XVideos 全球精选在线影视',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFFE50914),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildXVideosBrowsePage,
    ),
    'xhamster': const ResourceSiteItem(
      key: 'xhamster',
      label: 'xHamster',
      description: 'xHamster 全球知名成人视频',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFD32F2F),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildXhamsterBrowsePage,
    ),
    'xnxx': const ResourceSiteItem(
      key: 'xnxx',
      label: 'XNXX',
      description: 'XNXX 全球热门在线视频',
      icon: CupertinoIcons.play_circle,
      color: Color(0xFF0275D8),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildXnxxBrowsePage,
    ),
    'spankbang': const ResourceSiteItem(
      key: 'spankbang',
      label: 'SpankBang',
      description: 'SpankBang 极速影视流',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFF2196F3),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildSpankbangBrowsePage,
    ),
    'eporner': const ResourceSiteItem(
      key: 'eporner',
      label: 'EPorner',
      description: 'EPorner 4K / VR 影视精选',
      icon: CupertinoIcons.tv_fill,
      color: Color(0xFFE53935),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildEpornerBrowsePage,
    ),
    'hqporner': const ResourceSiteItem(
      key: 'hqporner',
      label: 'HQPorner',
      description: 'HQPorner 1080P 超清影视',
      icon: CupertinoIcons.film_fill,
      color: Color(0xFFFF9800),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildHqpornerBrowsePage,
    ),
    'pinse': const ResourceSiteItem(
      key: 'pinse',
      label: '91品色',
      description: '91品色 原创自拍影视',
      icon: CupertinoIcons.flame_fill,
      color: Color(0xFFFF8C00),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildPinseBrowsePage,
    ),
    'pornbox': const ResourceSiteItem(
      key: 'pornbox',
      label: 'PornBox',
      description: 'PornBox 欧美影视专区',
      icon: CupertinoIcons.cube_box_fill,
      color: Color(0xFF8E24AA),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildPornboxBrowsePage,
    ),
    'thothub': const ResourceSiteItem(
      key: 'thothub',
      label: 'Thothub',
      description: 'Thothub 极品精选模特与泄密视频',
      icon: CupertinoIcons.play_circle_fill,
      color: Color(0xFF00ADB5),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildThothubBrowsePage,
    ),
    'cosxplay': const ResourceSiteItem(
      key: 'cosxplay',
      label: 'CosXPlay',
      description: 'CosXPlay 高清Cosplay视频',
      icon: CupertinoIcons.play_rectangle,
      color: Color(0xFFE91E63),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildCosxplayBrowsePage,
    ),
    'cosplayporntube': const ResourceSiteItem(
      key: 'cosplayporntube',
      label: 'CosplayPornTube',
      description: 'CosplayPornTube 在线视频专区',
      icon: CupertinoIcons.film,
      color: Color(0xFFFF9800),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.video,
      builder: _buildCosplayporntubeBrowsePage,
    ),
    'coomer': const ResourceSiteItem(
      key: 'coomer',
      label: 'Coomer',
      description: 'Coomer 创作者付费内容社区',
      icon: CupertinoIcons.person_2_fill,
      color: Color(0xFF00AFF0),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.creator,
      builder: _buildCoomerBrowsePage,
    ),
    'twitter': const ResourceSiteItem(
      key: 'twitter',
      label: 'Twitter 榜',
      description: 'Twitter / TikTok 热门推特视频',
      icon: CupertinoIcons.chat_bubble_2_fill,
      color: Color(0xFF1D9BF0),
      mediaType: ResourceMediaType.video,
      category: ResourceCategory.creator,
      builder: _buildTwitterBrowsePage,
    ),
  };

  static Widget _buildJableBrowsePage(BuildContext _) => const JableBrowsePage(initialSiteIndex: 0);
  static Widget _buildMissavBrowsePage(BuildContext _) => const JableBrowsePage(initialSiteIndex: 1);
  static Widget _buildSupjavBrowsePage(BuildContext _) => const JableBrowsePage(initialSiteIndex: 2);
  static Widget _buildVideoBrowsePage(BuildContext _) => const VideoBrowsePage();
  static Widget _buildMztBrowsePage(BuildContext _) => const MztBrowsePage();
  static Widget _buildMisskonBrowsePage(BuildContext _) => const MisskonBrowsePage();
  static Widget _buildCoomerBrowsePage(BuildContext _) => const CoomerBrowsePage();
  static Widget _buildPinseBrowsePage(BuildContext _) => const PinseBrowsePage();
  static Widget _buildPornboxBrowsePage(BuildContext _) => const PornboxBrowsePage();
  static Widget _buildKuraaBrowsePage(BuildContext _) => const KuraaBrowsePage();
  static Widget _buildTwitterBrowsePage(BuildContext _) => const TwitterBrowsePage();
  static Widget _buildExHentaiBrowsePage(BuildContext _) => const ExHentaiBrowsePage();
  static Widget _buildPixibbBrowsePage(BuildContext _) => const PixibbBrowsePage();
  static Widget _buildCosplayteleBrowsePage(BuildContext _) => const CosplayteleBrowsePage();
  static Widget _buildNucosplayBrowsePage(BuildContext _) => const NucosplayBrowsePage();
  static Widget _buildCosvaultBrowsePage(BuildContext _) => const CosvaultBrowsePage();
  static Widget _buildGalleryepicBrowsePage(BuildContext _) => const GalleryepicBrowsePage();
  static Widget _buildHanime1BrowsePage(BuildContext _) => const Hanime1BrowsePage();
  static Widget _buildIwaraBrowsePage(BuildContext _) => const IwaraBrowsePage();
  static Widget _buildRule34VideoBrowsePage(BuildContext _) => const Rule34VideoBrowsePage();
  static Widget _buildEpornerBrowsePage(BuildContext _) => const EpornerBrowsePage();
  static Widget _buildHqpornerBrowsePage(BuildContext _) => const HqpornerBrowsePage();
  static Widget _buildSpankbangBrowsePage(BuildContext _) => const SpankbangBrowsePage();
  static Widget _buildPornhubBrowsePage(BuildContext _) => const PornhubBrowsePage();
  static Widget _buildXVideosBrowsePage(BuildContext _) => const XVideosBrowsePage();
  static Widget _buildCosxplayBrowsePage(BuildContext _) => const CosxplayBrowsePage();
  static Widget _buildCosplayporntubeBrowsePage(BuildContext _) => const CosplayporntubeBrowsePage();
  static Widget _buildXhamsterBrowsePage(BuildContext _) => const XhamsterBrowsePage();
  static Widget _buildXnxxBrowsePage(BuildContext _) => const XnxxBrowsePage();
  static Widget _buildNsfwpubBrowsePage(BuildContext _) => const NsfwpubBrowsePage();
  static Widget _buildThothubBrowsePage(BuildContext _) => const ThothubBrowsePage();
  static Widget _buildNjavBrowsePage(BuildContext _) => const NjavBrowsePage();
  static Widget _buildVjavBrowsePage(BuildContext _) => const VjavBrowsePage();
  static Widget _buildJavguruBrowsePage(BuildContext _) => const JavguruBrowsePage();
  static Widget _buildAv123BrowsePage(BuildContext _) => const Av123BrowsePage();
  static Widget _buildJavmostBrowsePage(BuildContext _) => const JavmostBrowsePage();
  static Widget _buildMemojavBrowsePage(BuildContext _) => const MemojavBrowsePage();
  static Widget _buildHohojBrowsePage(BuildContext _) => const HohojBrowsePage();

  static List<ResourceSiteItem> getOrderedSites(
    List<String>? orderKeys, {
    List<String>? hiddenKeys,
    ResourceMediaType? mediaType,
    ResourceCategory? category,
  }) {
    final List<String> baseline = (mediaType == null)
        ? defaultOrder
        : (mediaType == ResourceMediaType.image ? defaultImageOrder : defaultVideoOrder);

    final effectiveKeys = (orderKeys != null && orderKeys.isNotEmpty)
        ? List<String>.from(orderKeys)
        : List<String>.from(baseline);

    // Ensure any newly added site keys are present
    for (final k in baseline) {
      if (!effectiveKeys.contains(k)) {
        effectiveKeys.add(k);
      }
    }

    final hiddenSet = hiddenKeys?.toSet() ?? const <String>{};

    final List<ResourceSiteItem> result = [];
    for (final k in effectiveKeys) {
      if (hiddenSet.contains(k)) continue;
      final site = allSites[k];
      if (site == null) continue;
      if (mediaType != null && site.mediaType != mediaType) continue;
      if (category != null && site.category != category) continue;
      result.add(site);
    }
    return result;
  }

  static List<ResourceSiteItem> getAllOrderedSites(
    List<String>? orderKeys, {
    ResourceMediaType? mediaType,
  }) {
    return getOrderedSites(orderKeys, hiddenKeys: null, mediaType: mediaType);
  }

  static List<ResourceSiteItem> getImageSites(
    List<String>? orderKeys, {
    List<String>? hiddenKeys,
    ResourceCategory? category,
  }) {
    return getOrderedSites(
      orderKeys,
      hiddenKeys: hiddenKeys,
      mediaType: ResourceMediaType.image,
      category: category,
    );
  }

  static List<ResourceSiteItem> getVideoSites(
    List<String>? orderKeys, {
    List<String>? hiddenKeys,
    ResourceCategory? category,
  }) {
    return getOrderedSites(
      orderKeys,
      hiddenKeys: hiddenKeys,
      mediaType: ResourceMediaType.video,
      category: category,
    );
  }
}
