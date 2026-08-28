import 'package:flutter/cupertino.dart';

/// Supported adapter types
enum TwitterAdapterType {
  pektino,     // REST API: pektino.com, x-ero-anime.com, truvaze.com
  nextapi,     // Next.js API: twikeep.com, twiidol.com, xiaohuangniao.me
  twihub,      // SvelteKit REST API: twihub.net
  xhotvideo,   // HTML Scraper: xhotvideo.com
  monsnode,    // HTML Scraper + Redirect Resolver: monsnode.com
  htmlRanking, // HTML Scraper: twidouga.net, javtwi.com, twiigle.com, uraaka-times.com, twivideo.net
}

/// Represents an option in a filter (range / sort / tag / duration)
class TwitterFilterOption {
  final String id;
  final String label;
  final String? en;

  const TwitterFilterOption({
    required this.id,
    required this.label,
    this.en,
  });
}

/// Represents a site supported in the Twitter TikTok Ranking userscript
class TwitterSiteConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String description;
  final TwitterAdapterType adapterType;
  final IconData icon;
  final Color themeColor;
  final List<TwitterFilterOption> rangeOptions;
  final List<TwitterFilterOption> sortOptions;
  final List<TwitterFilterOption>? durationOptions;
  final List<TwitterFilterOption>? tagOptions;
  final bool isAnimeOnly;

  const TwitterSiteConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.description,
    required this.adapterType,
    required this.icon,
    required this.themeColor,
    required this.rangeOptions,
    required this.sortOptions,
    this.durationOptions,
    this.tagOptions,
    this.isAnimeOnly = false,
  });

  /// All 14 supported sites from the userscript
  static const List<TwitterSiteConfig> allSites = [
    // 1. Pektino
    TwitterSiteConfig(
      id: 'pektino',
      name: 'Pektino',
      baseUrl: 'https://pektino.com',
      description: 'Twitter 热门视频排行榜',
      adapterType: TwitterAdapterType.pektino,
      icon: CupertinoIcons.sparkles,
      themeColor: Color(0xFF1D9BF0),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '周榜', en: 'Weekly'),
        TwitterFilterOption(id: 'monthly', label: '月榜', en: 'Monthly'),
        TwitterFilterOption(id: 'all', label: '总榜', en: 'All Time'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'favorite', label: '按点赞', en: 'Likes'),
        TwitterFilterOption(id: 'pv', label: '按观看数', en: 'Views'),
        TwitterFilterOption(id: 'time', label: '按时长', en: 'Duration'),
        TwitterFilterOption(id: 'created', label: '最近添加', en: 'Recently Added'),
      ],
    ),

    // 2. TwiKeep
    TwitterSiteConfig(
      id: 'twikeep',
      name: 'TwiKeep',
      baseUrl: 'https://twikeep.com',
      description: 'Twitter 视频精选与排行',
      adapterType: TwitterAdapterType.nextapi,
      icon: CupertinoIcons.bookmark_fill,
      themeColor: Color(0xFF00BA7C),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '1周', en: '1 Week'),
        TwitterFilterOption(id: 'monthly', label: '1个月', en: '1 Month'),
        TwitterFilterOption(id: 'all', label: '1年', en: '1 Year'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'favorite', label: '最多点赞', en: 'Likes'),
        TwitterFilterOption(id: 'pv', label: '最多播放', en: 'Views'),
      ],
    ),

    // 3. TwiIdol
    TwitterSiteConfig(
      id: 'twiidol',
      name: 'TwiIdol',
      baseUrl: 'https://twiidol.com',
      description: 'Twitter 网红/偶像榜',
      adapterType: TwitterAdapterType.nextapi,
      icon: CupertinoIcons.star_fill,
      themeColor: Color(0xFFFF7A00),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '1周', en: '1 Week'),
        TwitterFilterOption(id: 'monthly', label: '1个月', en: '1 Month'),
        TwitterFilterOption(id: 'all', label: '1年', en: '1 Year'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '最多播放', en: 'Views'),
        TwitterFilterOption(id: 'favorite', label: '最多点赞', en: 'Likes'),
        TwitterFilterOption(id: 'recent', label: '最新视频', en: 'Latest'),
      ],
    ),

    // 4. X-Ero-Anime
    TwitterSiteConfig(
      id: 'x-ero-anime',
      name: 'X-Ero-Anime',
      baseUrl: 'https://x-ero-anime.com',
      description: '动漫/二次元推特榜',
      adapterType: TwitterAdapterType.pektino,
      isAnimeOnly: true,
      icon: CupertinoIcons.heart_fill,
      themeColor: Color(0xFFFF4081),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '周榜', en: 'Weekly'),
        TwitterFilterOption(id: 'monthly', label: '月榜', en: 'Monthly'),
        TwitterFilterOption(id: 'all', label: '总榜', en: 'All Time'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'favorite', label: '按点赞', en: 'Likes'),
        TwitterFilterOption(id: 'pv', label: '按观看数', en: 'Views'),
        TwitterFilterOption(id: 'created', label: '最近添加', en: 'Recently Added'),
      ],
    ),

    // 5. Truvaze
    TwitterSiteConfig(
      id: 'truvaze',
      name: 'Truvaze',
      baseUrl: 'https://truvaze.com',
      description: '推特综合精选热门榜',
      adapterType: TwitterAdapterType.pektino,
      icon: CupertinoIcons.flame_fill,
      themeColor: Color(0xFFFF5252),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '周榜', en: 'Weekly'),
        TwitterFilterOption(id: 'monthly', label: '月榜', en: 'Monthly'),
        TwitterFilterOption(id: 'all', label: '总榜', en: 'All Time'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'favorite', label: '按点赞', en: 'Likes'),
        TwitterFilterOption(id: 'pv', label: '按观看数', en: 'Views'),
      ],
    ),

    // 6. TwiHub
    TwitterSiteConfig(
      id: 'twihub',
      name: 'TwiHub',
      baseUrl: 'https://twihub.net',
      description: 'Twitter 综合热度排行榜',
      adapterType: TwitterAdapterType.twihub,
      icon: CupertinoIcons.layers_fill,
      themeColor: Color(0xFF7928CA),
      rangeOptions: [
        TwitterFilterOption(id: '1d', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: '7d', label: '7天榜', en: '7 Days'),
        TwitterFilterOption(id: '30d', label: '30天榜', en: '30 Days'),
        TwitterFilterOption(id: 'realtime', label: '最新', en: 'Latest'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '极高播放', en: 'Views'),
        TwitterFilterOption(id: 'favorite', label: '最多喜欢', en: 'Likes'),
      ],
    ),

    // 7. XHotVideo
    TwitterSiteConfig(
      id: 'xhotvideo',
      name: 'XHotVideo',
      baseUrl: 'https://xhotvideo.com',
      description: 'Twitter 成人短视频精选',
      adapterType: TwitterAdapterType.xhotvideo,
      icon: CupertinoIcons.play_circle_fill,
      themeColor: Color(0xFFE91E63),
      rangeOptions: [
        TwitterFilterOption(id: 'day', label: '今日热门', en: 'Daily'),
        TwitterFilterOption(id: 'week', label: '本周热门', en: 'Weekly'),
        TwitterFilterOption(id: 'month', label: '本月热门', en: 'Monthly'),
        TwitterFilterOption(id: 'all', label: '全部热门', en: 'All-Time'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'views', label: '播放最多', en: 'Views'),
        TwitterFilterOption(id: 'new', label: '最新发布', en: 'New'),
        TwitterFilterOption(id: 'duration', label: '时长最长', en: 'Duration'),
      ],
    ),

    // 8. Monsnode
    TwitterSiteConfig(
      id: 'monsnode',
      name: 'Monsnode',
      baseUrl: 'https://monsnode.com',
      description: 'Twitter 搜索与视频聚合',
      adapterType: TwitterAdapterType.monsnode,
      icon: CupertinoIcons.search_circle_fill,
      themeColor: Color(0xFF009688),
      rangeOptions: [
        TwitterFilterOption(id: '24h', label: '24小时榜', en: '24 Hours'),
        TwitterFilterOption(id: '3d', label: '3天榜', en: '3 Days'),
        TwitterFilterOption(id: '7d', label: '周榜', en: 'Weekly'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '综合排行', en: 'Rank'),
        TwitterFilterOption(id: 'favorite', label: '推荐排行', en: 'Top'),
      ],
    ),

    // 9. 小黄鸟
    TwitterSiteConfig(
      id: 'xiaohuangniao',
      name: '小黄鸟',
      baseUrl: 'https://xiaohuangniao.me',
      description: '华人/日韩精选推特榜',
      adapterType: TwitterAdapterType.nextapi,
      icon: CupertinoIcons.airplane,
      themeColor: Color(0xFFFFB300),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '1周', en: '1 Week'),
        TwitterFilterOption(id: 'monthly', label: '1个月', en: '1 Month'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'favorite', label: '最多点赞', en: 'Likes'),
        TwitterFilterOption(id: 'pv', label: '最多播放', en: 'Views'),
      ],
    ),

    // 10. TwiVideo
    TwitterSiteConfig(
      id: 'twivideo',
      name: 'TwiVideo',
      baseUrl: 'https://twivideo.net',
      description: 'Twitter 热门视频排行榜',
      adapterType: TwitterAdapterType.htmlRanking,
      icon: CupertinoIcons.film_fill,
      themeColor: Color(0xFF3F51B5),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '7天榜', en: '7 Days'),
        TwitterFilterOption(id: 'monthly', label: '30天榜', en: '30 Days'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '播放排行', en: 'Views'),
        TwitterFilterOption(id: 'favorite', label: '喜欢排行', en: 'Likes'),
      ],
    ),

    // 11. TwiDouga
    TwitterSiteConfig(
      id: 'twidouga',
      name: 'TwiDouga',
      baseUrl: 'https://www.twidouga.net',
      description: 'Twitter 视频保存热榜',
      adapterType: TwitterAdapterType.htmlRanking,
      icon: CupertinoIcons.tv_fill,
      themeColor: Color(0xFF00BCD4),
      rangeOptions: [
        TwitterFilterOption(id: 'realtime', label: '实时热度', en: 'Realtime'),
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '7天榜', en: '7 Days'),
        TwitterFilterOption(id: 'monthly', label: '月榜', en: '30 Days'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '播放排行', en: 'Views'),
        TwitterFilterOption(id: 'favorite', label: '点赞排行', en: 'Likes'),
      ],
    ),

    // 12. JavTwi
    TwitterSiteConfig(
      id: 'javtwi',
      name: 'JavTwi',
      baseUrl: 'https://javtwi.com',
      description: 'JAV/Cosplay 专属推特榜',
      adapterType: TwitterAdapterType.htmlRanking,
      icon: CupertinoIcons.person_crop_circle_badge_checkmark,
      themeColor: Color(0xFFE64A19),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '最新推荐', en: 'Latest'),
        TwitterFilterOption(id: 'weekly', label: '热门排行', en: 'Popular'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'favorite', label: '点赞排行', en: 'Likes'),
        TwitterFilterOption(id: 'pv', label: '播放排行', en: 'Views'),
      ],
    ),

    // 13. Uraaka Times
    TwitterSiteConfig(
      id: 'uraaka-times',
      name: 'Uraaka Times',
      baseUrl: 'https://uraaka-times.com',
      description: '裏垢女子推特排行榜',
      adapterType: TwitterAdapterType.htmlRanking,
      icon: CupertinoIcons.person_2_alt,
      themeColor: Color(0xFF9C27B0),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '今日精选', en: '24 Hours'),
        TwitterFilterOption(id: 'weekly', label: '周榜', en: 'Weekly'),
        TwitterFilterOption(id: 'monthly', label: '月榜', en: 'Monthly'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '热度排行', en: 'Views'),
        TwitterFilterOption(id: 'favorite', label: '推荐排行', en: 'Likes'),
      ],
    ),

    // 14. Twiigle
    TwitterSiteConfig(
      id: 'twiigle',
      name: 'Twiigle',
      baseUrl: 'https://twiigle.com',
      description: 'Twitter 视频聚合排行榜',
      adapterType: TwitterAdapterType.htmlRanking,
      icon: CupertinoIcons.compass_fill,
      themeColor: Color(0xFF2196F3),
      rangeOptions: [
        TwitterFilterOption(id: 'daily', label: '24小时', en: '24 Hours'),
        TwitterFilterOption(id: 'realtime', label: '实时', en: 'Realtime'),
        TwitterFilterOption(id: 'weekly', label: '7天榜', en: '7 Days'),
        TwitterFilterOption(id: 'monthly', label: '30天榜', en: '30 Days'),
      ],
      sortOptions: [
        TwitterFilterOption(id: 'pv', label: '播放排行', en: 'Views'),
        TwitterFilterOption(id: 'favorite', label: '点赞排行', en: 'Likes'),
      ],
    ),
  ];

  static TwitterSiteConfig get defaultSite => allSites.first;

  static TwitterSiteConfig findById(String id) {
    return allSites.firstWhere((s) => s.id == id, orElse: () => defaultSite);
  }
}
