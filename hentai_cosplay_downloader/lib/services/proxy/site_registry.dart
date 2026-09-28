/// Registry of all websites/modules in the app with their domains and proxy defaults.
class SiteMetadata {
  final String key;
  final String name;
  final String icon;
  final List<String> domainPatterns;
  final bool defaultProxy;
  final String description;

  const SiteMetadata({
    required this.key,
    required this.name,
    required this.icon,
    required this.domainPatterns,
    this.defaultProxy = true,
    this.description = '',
  });

  String get displayName => name;
  List<String> get primaryDomains => domainPatterns;

  bool matchesHost(String rawHost) {
    var lowerHost = rawHost.toLowerCase().trim();
    if (lowerHost.startsWith('[') && lowerHost.contains(']')) {
      lowerHost = lowerHost.substring(1, lowerHost.indexOf(']'));
    } else if (lowerHost.contains(':') && lowerHost.indexOf(':') == lowerHost.lastIndexOf(':')) {
      lowerHost = lowerHost.substring(0, lowerHost.indexOf(':'));
    }
    for (final pattern in domainPatterns) {
      final lowerPattern = pattern.toLowerCase().trim();
      if (lowerHost == lowerPattern || lowerHost.endsWith('.$lowerPattern')) {
        return true;
      }
    }
    return false;
  }
}

class SiteRegistry {
  static const List<SiteMetadata> allSites = [
    // 1. Foreign restricted video sites (Default: Proxy)
    SiteMetadata(
      key: 'pornhub',
      name: 'Pornhub',
      icon: '🟧',
      domainPatterns: ['pornhub.com', 'phncdn.com'],
      defaultProxy: true,
      description: '全球最大成人视频，需代理连接与下载',
    ),
    SiteMetadata(
      key: 'iwara',
      name: 'Iwara (里表站)',
      icon: '🎀',
      domainPatterns: ['iwara.tv'],
      defaultProxy: true,
      description: '3D MMD 动漫二次元创作者社区',
    ),
    SiteMetadata(
      key: 'hanime1',
      name: 'Hanime1',
      icon: '🌸',
      domainPatterns: ['hanime1.me', 'hembed.com'],
      defaultProxy: true,
      description: '高清正版里番与动漫番剧',
    ),
    SiteMetadata(
      key: 'jable',
      name: 'JableTV',
      icon: '📺',
      domainPatterns: ['jable.tv', 'fs1.app', 'mushroomtrack.com'],
      defaultProxy: true,
      description: '日韩高清影视与流媒体',
    ),
    SiteMetadata(
      key: 'rule34video',
      name: 'Rule34Video',
      icon: '🎮',
      domainPatterns: ['rule34video.com'],
      defaultProxy: true,
      description: '游戏与 3D 角色扮演同人视频',
    ),
    SiteMetadata(
      key: 'eporner',
      name: 'Eporner',
      icon: '⚡',
      domainPatterns: ['eporner.com'],
      defaultProxy: true,
      description: '4K/1080P 高清原盘视频',
    ),
    SiteMetadata(
      key: 'hqporner',
      name: 'HQPorner',
      icon: '💎',
      domainPatterns: ['hqporner.com'],
      defaultProxy: true,
      description: '超清短视频与精选集',
    ),
    SiteMetadata(
      key: 'spankbang',
      name: 'SpankBang',
      icon: '🔞',
      domainPatterns: ['spankbang.com', 'spankbang.party'],
      defaultProxy: true,
      description: '高清无码海外视频站',
    ),
    SiteMetadata(
      key: 'xvideos',
      name: 'XVideos',
      icon: '🔴',
      domainPatterns: ['xvideos.com', 'xvideos-cdn.com'],
      defaultProxy: true,
      description: '老牌海外综合视频库',
    ),
    SiteMetadata(
      key: 'xhamster',
      name: 'XHamster',
      icon: '🐹',
      domainPatterns: ['xhamster.com'],
      defaultProxy: true,
      description: '全球综合视频社区',
    ),
    SiteMetadata(
      key: 'xnxx',
      name: 'XNXX',
      icon: '🔵',
      domainPatterns: ['xnxx.com', 'xnxx-cdn.com'],
      defaultProxy: true,
      description: '超大海量高清视频库',
    ),
    SiteMetadata(
      key: 'memojav',
      name: 'MemoJAV',
      icon: '🎬',
      domainPatterns: ['memojav.com'],
      defaultProxy: true,
      description: '番号检索与 4K 超清在线播放',
    ),
    SiteMetadata(
      key: 'njav',
      name: 'NJAV',
      icon: '🇯🇵',
      domainPatterns: ['njav.tv'],
      defaultProxy: true,
      description: '日韩热门番号视频专区',
    ),
    SiteMetadata(
      key: 'javguru',
      name: 'JAVGuru',
      icon: '🏯',
      domainPatterns: ['jav.guru'],
      defaultProxy: true,
      description: '高清番号资源聚合',
    ),
    SiteMetadata(
      key: 'javmost',
      name: 'JAVMost',
      icon: '🏮',
      domainPatterns: ['javmost.cx', 'javmost.com'],
      defaultProxy: true,
      description: '日系番号流媒体聚合',
    ),
    SiteMetadata(
      key: 'vjav',
      name: 'VJAV',
      icon: '📽️',
      domainPatterns: ['vjav.com'],
      defaultProxy: true,
      description: '经典热门流媒体视频',
    ),
    SiteMetadata(
      key: 'av123',
      name: 'AV123',
      icon: '📼',
      domainPatterns: ['av123.com', 'av123.tv'],
      defaultProxy: true,
      description: '综合在线视频专区',
    ),
    SiteMetadata(
      key: 'nsfwpub',
      name: 'NSFWPub',
      icon: '🍻',
      domainPatterns: ['nsfwpub.com'],
      defaultProxy: true,
      description: '社区精选短视频',
    ),
    SiteMetadata(
      key: 'thothub',
      name: 'ThotHub',
      icon: '🌟',
      domainPatterns: ['thothub.lol', 'thothub.to', 'thothub.is'],
      defaultProxy: true,
      description: '网红与社交媒体专区',
    ),
    SiteMetadata(
      key: 'hohoj',
      name: 'HoHoJ 影视',
      icon: '🍿',
      domainPatterns: ['hohoj.com', 'hoho.tv'],
      defaultProxy: true,
      description: '高清番号与热播剧集',
    ),
    SiteMetadata(
      key: 'cosplayporntube',
      name: 'CosplayPornTube',
      icon: '🎭',
      domainPatterns: ['cosplayporntube.com'],
      defaultProxy: true,
      description: '角色扮演视频专区',
    ),

    // 2. Picture and creator sites (Default: Proxy)
    SiteMetadata(
      key: 'coomer',
      name: 'Coomer',
      icon: '🎨',
      domainPatterns: ['coomer.su', 'coomer.party'],
      defaultProxy: true,
      description: 'OnlyFans / Fansly 创作者图集同步',
    ),
    SiteMetadata(
      key: 'misskon',
      name: 'MissKon',
      icon: '💃',
      domainPatterns: ['misskon.com'],
      defaultProxy: true,
      description: '精选高质量 Cosplay 写真图集',
    ),
    SiteMetadata(
      key: 'twitter',
      name: 'Twitter 排行榜',
      icon: '🐦',
      domainPatterns: ['twitter.com', 'x.com', 'twimg.com'],
      defaultProxy: true,
      description: 'Twitter 热门 Coser 推文与榜单',
    ),
    SiteMetadata(
      key: 'exhentai',
      name: 'E-Hentai / ExHentai',
      icon: '🐼',
      domainPatterns: ['e-hentai.org', 'exhentai.org'],
      defaultProxy: true,
      description: '全球同人志与写真档案馆',
    ),
    SiteMetadata(
      key: 'cosplaytele',
      name: 'CosplayTele',
      icon: '📸',
      domainPatterns: ['cosplaytele.com'],
      defaultProxy: true,
      description: 'Cosplay 电报精选图集',
    ),
    SiteMetadata(
      key: 'nucosplay',
      name: 'NuCosplay',
      icon: '✨',
      domainPatterns: ['nucosplay.com'],
      defaultProxy: true,
      description: '欧美与亚裔高清写真',
    ),
    SiteMetadata(
      key: 'cosvault',
      name: 'CosVault',
      icon: '🏛️',
      domainPatterns: ['cosvault.com'],
      defaultProxy: true,
      description: 'Cosplay 档案馆图集',
    ),
    SiteMetadata(
      key: 'galleryepic',
      name: 'GalleryEpic',
      icon: '🖼️',
      domainPatterns: ['galleryepic.com'],
      defaultProxy: true,
      description: '画廊级超清写真',
    ),
    SiteMetadata(
      key: 'cosxplay',
      name: 'CosXPlay',
      icon: '👗',
      domainPatterns: ['cosxplay.com'],
      defaultProxy: true,
      description: '角色扮演摄影精选',
    ),
    SiteMetadata(
      key: 'pornbox',
      name: 'PornBox',
      icon: '📦',
      domainPatterns: ['pornbox.com'],
      defaultProxy: true,
      description: '海外综合写真图库',
    ),
    SiteMetadata(
      key: 'pixibb',
      name: 'PixiBB',
      icon: '📷',
      domainPatterns: ['pixibb.com'],
      defaultProxy: true,
      description: '外链高清原图托管',
    ),

    // 3. Direct accessible sites (Default: Direct for max speed)
    SiteMetadata(
      key: 'mzt',
      name: '妹子图 (MZT)',
      icon: '🌸',
      domainPatterns: ['mzitu.com', 'i.meizitu.net', 't1.meizitu.net'],
      defaultProxy: false,
      description: '国内高速节点轮询，直连秒开更顺畅',
    ),
    SiteMetadata(
      key: 'hc_gallery',
      name: 'Hentai Cosplay 主站',
      icon: '👑',
      domainPatterns: ['hentai-cosplays.com', 'hentai-cosplay-xxx.com', 'hccdn.com', 'hentai-cosplay.com'],
      defaultProxy: false,
      description: '国内直连访问速度快，节省代理流量',
    ),
    SiteMetadata(
      key: 'pinse',
      name: '品色 (Pinse)',
      icon: '💋',
      domainPatterns: ['pinse.org'],
      defaultProxy: false,
      description: '免翻墙高速直连写真',
    ),
    SiteMetadata(
      key: 'kuraa',
      name: 'Kuraa',
      icon: '🍃',
      domainPatterns: ['kuraa.org'],
      defaultProxy: false,
      description: '免翻墙镜像图集专区',
    ),
  ];

  static final Map<String, SiteMetadata> _siteMap = {
    for (final s in allSites) s.key: s,
    // Aliases
    'hc': allSites.firstWhere((s) => s.key == 'hc_gallery'),
  };

  /// Returns metadata by site key
  static SiteMetadata? getSite(String key) => _siteMap[key];

  /// Finds which site a given host belongs to. Returns null if unknown.
  static SiteMetadata? matchSite(String host) {
    for (final s in allSites) {
      if (s.matchesHost(host)) {
        return s;
      }
    }
    return null;
  }

  /// Generates the default toggles map
  static Map<String, bool> getDefaultToggles() {
    return {
      for (final s in allSites) s.key: s.defaultProxy,
    };
  }
}
