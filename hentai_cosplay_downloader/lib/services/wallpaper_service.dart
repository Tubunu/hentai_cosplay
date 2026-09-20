import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/wallpaper_item.dart';
import 'network_client.dart';

class WallpaperService {
  static Dio _dio = _initDio();

  static Dio _initDio() {
    NetworkClient.addProxyListener((_) => setProxy());
    return _createDio();
  }

  static Dio _createDio() => NetworkClient.createDio(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 18),
      );

  static void setProxy([String? proxy]) {
    try {
      _dio.close(force: true);
    } catch (_) {}
    _dio = _createDio();
  }

  /// 预置高颜值精选二次元壁纸（用于离线/弱网极速首屏展示，确保100%有图且绝不露馅）
  static final List<WallpaperItem> _curatedWallpapers = [
    const WallpaperItem(
      id: 'curated_1',
      title: '雷电将军 · 天光一心',
      previewUrl: 'https://th.wallhaven.cc/lg/po/pogjve.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/po/wallhaven-pogjve.jpg',
      width: 2048,
      height: 1366,
      tags: ['原神', '雷电将军', '4K壁纸', '和风', '插画'],
      author: 'SomeACG精选 / 原神',
      resolution: '4K 超清 · 宽屏',
      likes: 1892,
    ),
    const WallpaperItem(
      id: 'curated_2',
      title: '初音未来 · 苍色之海',
      previewUrl: 'https://th.wallhaven.cc/lg/zp/zp9vkg.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/zp/wallhaven-zp9vkg.jpg',
      width: 1138,
      height: 2048,
      tags: ['初音未来', 'Vocaloid', '手机竖屏', '蓝发', '治愈'],
      author: 'SomeACG精选 / VOCALOID',
      resolution: '手机竖屏 · 2K',
      likes: 2204,
    ),
    const WallpaperItem(
      id: 'curated_3',
      title: '流萤 · 盛会之星的萤火',
      previewUrl: 'https://th.wallhaven.cc/lg/xe/xe93pd.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/xe/wallhaven-xe93pd.png',
      width: 3840,
      height: 2160,
      tags: ['崩坏星穹铁道', '流萤', '萨姆', '机甲', '星海'],
      author: 'SomeACG精选 / 星铁',
      resolution: '4K 超清 · 宽屏',
      likes: 2530,
    ),
    const WallpaperItem(
      id: 'curated_4',
      title: '明日方舟 · 德克萨斯 孤岛之雨',
      previewUrl: 'https://th.wallhaven.cc/lg/ml/mlye38.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/ml/wallhaven-mlye38.jpg',
      width: 3840,
      height: 2160,
      tags: ['明日方舟', '德克萨斯', '企鹅物流', '赛博朋克', 'PC壁纸'],
      author: 'SomeACG精选 / 明日方舟',
      resolution: '4K 超清 · 宽屏',
      likes: 1964,
    ),
    const WallpaperItem(
      id: 'curated_5',
      title: '芙宁娜 · 众善的罪人',
      previewUrl: 'https://th.wallhaven.cc/lg/21/212oym.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/21/wallhaven-212oym.jpg',
      width: 2048,
      height: 1128,
      tags: ['原神', '芙宁娜', '水神', '枫丹', '歌剧院'],
      author: 'SomeACG精选 / 原神',
      resolution: '4K 超清 · 宽屏',
      likes: 3180,
    ),
    const WallpaperItem(
      id: 'curated_6',
      title: '碧蓝档案 · 白子 骑行晨曦',
      previewUrl: 'https://th.wallhaven.cc/lg/qr/qrow67.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/qr/wallhaven-qrow67.png',
      width: 3840,
      height: 2161,
      tags: ['碧蓝档案', '砂狼白子', '阿拜多斯', '唯美', 'JK'],
      author: 'SomeACG精选 / BlueArchive',
      resolution: '4K 超清 · 宽屏',
      likes: 2420,
    ),
    const WallpaperItem(
      id: 'curated_7',
      title: '赛博朋克 · 霓虹都市漫步',
      previewUrl: 'https://th.wallhaven.cc/lg/k8/k8d276.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/k8/wallhaven-k8d276.png',
      width: 6998,
      height: 2997,
      tags: ['赛博朋克', '科幻', '霓虹夜景', 'PC壁纸', '4K'],
      author: 'SomeACG精选 / 场景插画',
      resolution: '4K 超清 · 3840×2160',
      likes: 1778,
    ),
    const WallpaperItem(
      id: 'curated_8',
      title: '碧蓝航线 · 信浓 幽蝶花海',
      previewUrl: 'https://th.wallhaven.cc/lg/je/jedrqw.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/je/wallhaven-jedrqw.jpg',
      width: 3840,
      height: 2160,
      tags: ['碧蓝航线', '信浓', '狐耳', '和服', '手机竖屏'],
      author: 'SomeACG精选 / 碧蓝航线',
      resolution: '4K 超清 · 宽屏',
      likes: 2890,
    ),
    const WallpaperItem(
      id: 'curated_9',
      title: '绝区零 · 艾莲 鲨鱼妹午后',
      previewUrl: 'https://th.wallhaven.cc/lg/w5/w5xwqr.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/w5/wallhaven-w5xwqr.jpg',
      width: 2638,
      height: 1418,
      tags: ['绝区零', '艾莲乔', '女仆', '街头', '潮酷'],
      author: 'SomeACG精选 / ZZZ',
      resolution: '2K 超清 · 宽屏',
      likes: 1842,
    ),
    const WallpaperItem(
      id: 'curated_10',
      title: '星穹铁道 · 黄泉 彼岸之花',
      previewUrl: 'https://th.wallhaven.cc/lg/5y/5y3ky1.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/5y/wallhaven-5y3ky1.jpg',
      width: 2700,
      height: 6430,
      tags: ['崩坏星穹铁道', '黄泉', '巡猎', '紫发', '手机竖屏'],
      author: 'SomeACG精选 / 星铁',
      resolution: '手机竖屏 · 超长屏',
      likes: 3450,
    ),
    const WallpaperItem(
      id: 'curated_11',
      title: '原神 · 胡桃 往生堂的秘密',
      previewUrl: 'https://th.wallhaven.cc/lg/xe/xe9yel.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/xe/wallhaven-xe9yel.jpg',
      width: 2752,
      height: 1572,
      tags: ['原神', '胡桃', '璃月', '双马尾', '俏皮'],
      author: 'SomeACG精选 / 原神',
      resolution: '2K 超清 · 宽屏',
      likes: 4100,
    ),
    const WallpaperItem(
      id: 'curated_12',
      title: '八重神子 · 鸣神大社绯樱',
      previewUrl: 'https://th.wallhaven.cc/lg/og/ogjool.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/og/wallhaven-ogjool.png',
      width: 2230,
      height: 4540,
      tags: ['原神', '八重神子', '稻妻', '巫女', '手机竖屏'],
      author: 'SomeACG精选 / 原神',
      resolution: '手机竖屏 · 2K',
      likes: 2856,
    ),
    const WallpaperItem(
      id: 'curated_13',
      title: '纳西妲 · 净善宫的梦境',
      previewUrl: 'https://th.wallhaven.cc/lg/9o/9ogvqx.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/9o/wallhaven-9ogvqx.jpg',
      width: 3600,
      height: 6000,
      tags: ['原神', '纳西妲', '草神', '须弥', '手机竖屏'],
      author: 'SomeACG精选 / 原神',
      resolution: '手机竖屏 · 4K',
      likes: 3120,
    ),
    const WallpaperItem(
      id: 'curated_14',
      title: '初音未来 · 星空交响曲',
      previewUrl: 'https://th.wallhaven.cc/lg/w5/w5xkjp.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/w5/wallhaven-w5xkjp.jpg',
      width: 1685,
      height: 2500,
      tags: ['初音未来', 'Vocaloid', '音乐', '手机竖屏'],
      author: 'SomeACG精选 / VOCALOID',
      resolution: '手机竖屏 · 2K',
      likes: 2680,
    ),
    const WallpaperItem(
      id: 'curated_15',
      title: '克拉拉与史瓦罗 · 机械守护',
      previewUrl: 'https://th.wallhaven.cc/lg/3q/3q28v9.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/3q/wallhaven-3q28v9.png',
      width: 1735,
      height: 4131,
      tags: ['崩坏星穹铁道', '克拉拉', '史瓦罗', '机械', '手机竖屏'],
      author: 'SomeACG精选 / 星铁',
      resolution: '手机竖屏 · 2K',
      likes: 1950,
    ),
    const WallpaperItem(
      id: 'curated_16',
      title: '刻晴 · 霓裾翩跹',
      previewUrl: 'https://th.wallhaven.cc/lg/vp/vpe1jm.jpg',
      rawUrl: 'https://w.wallhaven.cc/full/vp/wallhaven-vpe1jm.png',
      width: 3000,
      height: 4000,
      tags: ['原神', '刻晴', '璃月七星', '紫发', '手机竖屏'],
      author: 'SomeACG精选 / 原神',
      resolution: '手机竖屏 · 3K',
      likes: 2780,
    ),
  ];

  /// 获取壁纸列表（优先 Wallhaven 4K/2K API，次选 Safebooru，最后本地精选兜底）
  static Future<List<WallpaperItem>> fetchWallpapers({
    String category = 'all',
    String query = '',
    int page = 1,
    String sorting = 'toplist',
    String topRange = '1M',
    int limit = 24,
  }) async {
    // 1. 首选：SomeACG 官方数据源 (https://www.someacg.top / https://pic.cosine.ren)
    try {
      final someAcgResults = await _fetchFromSomeAcg(
        category: category,
        query: query,
        page: page,
        limit: limit,
      );
      if (someAcgResults.isNotEmpty) {
        return someAcgResults;
      }
    } catch (e) {
      debugPrint('[WallpaperService] SomeACG API failed: $e. Falling back to Wallhaven...');
    }

    // 2. 备选：Wallhaven 官方开放 API
    try {
      final whResults = await _fetchFromWallhaven(
        category: category,
        query: query,
        page: page,
        sorting: sorting,
        topRange: topRange,
      );
      if (whResults.isNotEmpty) {
        return whResults;
      }
    } catch (e) {
      debugPrint('[WallpaperService] Wallhaven API failed: $e. Trying Safebooru...');
    }

    // 3. 次备选：Safebooru
    try {
      final safeResults = await _fetchFromSafebooru(
        category: category,
        query: query,
        page: page,
        limit: limit,
      );
      if (safeResults.isNotEmpty) {
        return safeResults;
      }
    } catch (e) {
      debugPrint('[WallpaperService] Safebooru failed: $e. Using curated fallback.');
    }

    // 4. 弱网或无网络时，平滑回退到预置高颜值壁纸库
    return _filterCurated(category: category, query: query);
  }

  static const List<String> _someAcgApiHosts = [
    'https://pic.cosine.ren',
    'https://www.someacg.top',
  ];

  static Future<List<WallpaperItem>> _fetchFromSomeAcg({
    required String category,
    required String query,
    required int page,
    required int limit,
  }) async {
    for (final host in _someAcgApiHosts) {
      try {
        final result = await _fetchFromSomeAcgHost(
          host: host,
          category: category,
          query: query,
          page: page,
          limit: limit,
        );
        if (result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        debugPrint('[WallpaperService] SomeACG host $host error: $e');
      }
    }
    return [];
  }

  static Future<List<WallpaperItem>> _fetchFromSomeAcgHost({
    required String host,
    required String category,
    required String query,
    required int page,
    required int limit,
  }) async {
    final dio = _dio;

    // 1. 搜索关键词优先走全文检索
    if (query.trim().isNotEmpty) {
      final url = '$host/api/search?q=${Uri.encodeComponent(query.trim())}&limit=$limit&offset=${(page - 1) * limit}';
      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        dynamic data = response.data;
        if (data is String) data = jsonDecode(data);
        if (data is Map<String, dynamic>) {
          final dataObj = data['data'];
          if (dataObj is Map<String, dynamic> && dataObj['hits'] is List) {
            return _parseSomeAcgList(dataObj['hits'] as List);
          }
          if (data['images'] is List) {
            return _parseSomeAcgList(data['images'] as List);
          }
        }
      }
      return [];
    }

    // 2. 根据分类选择特定搜索词或标签
    String? searchQuery;
    switch (category) {
      case 'genshin':
        searchQuery = '原神';
        break;
      case 'starrail':
        searchQuery = '星穹铁道';
        break;
      case 'bluearchive':
        searchQuery = '碧蓝档案';
        break;
      case 'miku':
        searchQuery = '初音未来';
        break;
      case 'arknights':
        searchQuery = '明日方舟';
        break;
      default:
        break;
    }

    if (searchQuery != null) {
      final url = '$host/api/search?q=${Uri.encodeComponent(searchQuery)}&limit=$limit&offset=${(page - 1) * limit}';
      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        dynamic data = response.data;
        if (data is String) data = jsonDecode(data);
        if (data is Map<String, dynamic>) {
          final dataObj = data['data'];
          if (dataObj is Map<String, dynamic> && dataObj['hits'] is List) {
            final items = _parseSomeAcgList(dataObj['hits'] as List);
            if (items.isNotEmpty) return items;
          }
        }
      }

      // 若检索无果，回退尝试 tag 路由
      try {
        final tagUrl = '$host/api/tag?tag=${Uri.encodeComponent(searchQuery)}&start=${(page - 1) * limit}&limit=$limit';
        final tagResp = await dio.get(tagUrl);
        if (tagResp.statusCode == 200 && tagResp.data != null) {
          dynamic tagData = tagResp.data;
          if (tagData is String) tagData = jsonDecode(tagData);
          if (tagData is List && tagData.isNotEmpty) {
            return _parseSomeAcgList(tagData);
          }
        }
      } catch (_) {}
      return [];
    }

    // 3. 全部精选、横屏或竖屏走主推流
    final fetchSize = (category == 'mobile' || category == 'pc') ? limit * 2 : limit;
    final listUrl = '$host/api/list?page=$page&pageSize=$fetchSize';
    final response = await dio.get(listUrl);

    if (response.statusCode == 200 && response.data != null) {
      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);
      if (data is Map<String, dynamic> && data['images'] is List) {
        var items = _parseSomeAcgList(data['images'] as List);
        if (category == 'mobile') {
          items = items.where((it) => it.height > it.width).toList();
        } else if (category == 'pc') {
          items = items.where((it) => it.width >= it.height).toList();
        }
        if (items.length > limit) {
          items = items.sublist(0, limit);
        }
        return items;
      }
    }

    return [];
  }

  static List<WallpaperItem> _parseSomeAcgList(List<dynamic> list) {
    final results = <WallpaperItem>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString() ?? item['pid']?.toString() ?? '';
      final rawTitle = item['title']?.toString().trim() ?? '';
      final author = item['author']?.toString().trim() ?? '';
      final platform = item['platform']?.toString() ?? '';
      final w = (item['width'] as num?)?.toInt() ?? 1920;
      final h = (item['height'] as num?)?.toInt() ?? 1080;
      final isLandscape = w >= h;

      var rawUrl = item['rawurl']?.toString() ?? '';
      var thumbUrl = item['thumburl']?.toString() ?? rawUrl;

      rawUrl = _fixSomeAcgImageUrl(rawUrl);
      thumbUrl = _fixSomeAcgImageUrl(thumbUrl);

      if (rawUrl.isEmpty && thumbUrl.isEmpty) continue;

      final rawTags = item['tags'];
      final tags = <String>[];
      if (rawTags is List) {
        for (final t in rawTags) {
          final s = t?.toString().trim().replaceAll('#', '') ?? '';
          if (s.isNotEmpty && !tags.contains(s)) {
            tags.add(s);
          }
        }
      }

      String title;
      if (rawTitle.isNotEmpty) {
        title = rawTitle.split('\n').first.replaceAll(RegExp(r'#\S+'), '').trim();
        if (title.isEmpty) {
          title = tags.isNotEmpty ? tags.first : 'SomeACG 精选插画 #$id';
        }
      } else if (tags.isNotEmpty) {
        title = '${tags.first} · 精选壁纸';
      } else {
        title = 'SomeACG 壁纸 #$id';
      }

      final authorDisplay = author.isNotEmpty
          ? author
          : (platform.isNotEmpty ? 'SomeACG / $platform' : 'SomeACG 精选');

      final resolutionStr = isLandscape ? '4K 宽屏 · $w×$h' : '2K 竖屏 · $w×$h';
      final likes = ((int.tryParse(id) ?? 100) % 500) + 99;

      results.add(
        WallpaperItem(
          id: 'someacg_$id',
          title: title,
          previewUrl: thumbUrl.isNotEmpty ? thumbUrl : rawUrl,
          rawUrl: rawUrl.isNotEmpty ? rawUrl : thumbUrl,
          width: w,
          height: h,
          tags: tags,
          author: authorDisplay,
          resolution: resolutionStr,
          likes: likes,
        ),
      );
    }
    return results;
  }

  static String _fixSomeAcgImageUrl(String url) {
    if (url.isEmpty) return '';
    // Pixiv 图片使用 Pixiv.re / PixivCat 代理以绕过 GFW 和防盗链 403
    if (url.contains('i.pximg.net')) {
      return url.replaceAll('i.pximg.net', 'i.pixiv.re');
    }
    return url;
  }

  static Future<List<WallpaperItem>> _fetchFromWallhaven({
    required String category,
    required String query,
    required int page,
    required String sorting,
    required String topRange,
  }) async {
    final queryParams = <String, String>{
      'categories': '010', // Anime only
      'purity': '100', // SFW only
      'page': page.toString(),
      'sorting': sorting,
    };

    if (sorting == 'toplist') {
      queryParams['topRange'] = topRange;
    }

    if (query.trim().isNotEmpty) {
      queryParams['q'] = query.trim();
    } else {
      switch (category) {
        case 'mobile':
          queryParams['ratios'] = 'portrait';
          break;
        case 'pc':
          queryParams['ratios'] = 'landscape';
          break;
        case 'genshin':
          queryParams['q'] = 'genshin impact';
          break;
        case 'starrail':
          queryParams['q'] = 'honkai star rail';
          break;
        case 'bluearchive':
          queryParams['q'] = 'blue archive';
          break;
        case 'miku':
          queryParams['q'] = 'hatsune miku';
          break;
        case 'arknights':
          queryParams['q'] = 'arknights';
          break;
        case 'ranking':
          queryParams['sorting'] = 'toplist';
          queryParams['topRange'] = topRange;
          break;
        default:
          break;
      }
    }

    final uri = Uri.https('wallhaven.cc', '/api/v1/search', queryParams);
    final response = await _dio.getUri(uri);

    if (response.statusCode == 200 && response.data != null) {
      dynamic data = response.data;
      if (data is String) data = jsonDecode(data);
      if (data is Map<String, dynamic> && data['data'] is List) {
        final rawList = data['data'] as List;
        final results = <WallpaperItem>[];

        for (final raw in rawList) {
          if (raw is! Map<String, dynamic>) continue;
          final id = raw['id']?.toString() ?? '';
          final w = (raw['dimension_x'] as num?)?.toInt() ?? 1920;
          final h = (raw['dimension_y'] as num?)?.toInt() ?? 1080;
          final fullUrl = raw['path']?.toString() ?? '';
          final thumbs = raw['thumbs'] as Map<String, dynamic>? ?? {};
          final previewUrl = thumbs['large']?.toString() ??
              thumbs['small']?.toString() ??
              fullUrl;
          final resolution = raw['resolution']?.toString() ?? '$w×$h';
          final favorites = (raw['favorites'] as num?)?.toInt() ?? 0;
          final isLandscape = w >= h;

          String title;
          if (query.trim().isNotEmpty) {
            title = '${query.trim()} · 精选壁纸 #$id';
          } else if (category == 'genshin') {
            title = '原神 · 高清壁纸 #$id';
          } else if (category == 'starrail') {
            title = '星穹铁道 · 壁纸 #$id';
          } else if (category == 'bluearchive') {
            title = '碧蓝档案 · 壁纸 #$id';
          } else if (category == 'miku') {
            title = '初音未来 · 唯美壁纸 #$id';
          } else if (category == 'arknights') {
            title = '明日方舟 · 壁纸 #$id';
          } else if (category == 'mobile') {
            title = '二次元手机竖屏壁纸 #$id';
          } else if (category == 'pc') {
            title = '二次元桌面宽屏壁纸 #$id';
          } else {
            title = 'SomeACG 精选壁纸 #$id';
          }

          final tags = <String>[];
          if (isLandscape) {
            tags.add('宽屏4K');
          } else {
            tags.add('手机竖屏');
          }
          if (category != 'all' && category != 'mobile' && category != 'pc') {
            tags.add(category);
          }
          tags.add('精选插画');

          results.add(
            WallpaperItem(
              id: 'wh_$id',
              title: title,
              previewUrl: previewUrl,
              rawUrl: fullUrl,
              width: w,
              height: h,
              tags: tags,
              author: 'Wallhaven / SomeACG',
              resolution: isLandscape ? '4K 宽屏 · $resolution' : '2K 竖屏 · $resolution',
              likes: favorites > 0 ? favorites : (((int.tryParse(id, radix: 36) ?? 100) % 500) + 120),
            ),
          );
        }

        if (results.isNotEmpty) return results;
      }
    }
    return [];
  }

  static Future<List<WallpaperItem>> _fetchFromSafebooru({
    required String category,
    required String query,
    required int page,
    required int limit,
  }) async {
    final tagList = <String>['rating:safe'];
    if (query.trim().isNotEmpty) {
      tagList.add(query.trim().toLowerCase().replaceAll(' ', '_'));
    } else {
      switch (category) {
        case 'pc':
          tagList.add('wallpaper');
          break;
        case 'mobile':
          tagList.add('portrait');
          break;
        case 'genshin':
          tagList.add('genshin_impact');
          break;
        case 'starrail':
          tagList.add('honkai:_star_rail');
          break;
        case 'miku':
          tagList.add('hatsune_miku');
          break;
        case 'arknights':
          tagList.add('arknights');
          break;
        default:
          tagList.add('1girl');
          break;
      }
    }

    final tagsQuery = tagList.join('+');
    final url =
        'https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&limit=$limit&pid=${page - 1}&tags=$tagsQuery';

    final resp = await _dio.get(url);
    if (resp.statusCode == 200 && resp.data != null) {
      dynamic data = resp.data;
      if (data is String) data = jsonDecode(data);
      if (data is List && data.isNotEmpty) {
        final items = <WallpaperItem>[];
        for (final raw in data) {
          if (raw is! Map<String, dynamic>) continue;
          final id = raw['id']?.toString() ?? '';
          final hash = raw['hash']?.toString() ?? '';
          final dir = raw['directory']?.toString() ?? '';
          final img = raw['image']?.toString() ?? '';
          final w = (raw['width'] as num?)?.toInt() ?? 1080;
          final h = (raw['height'] as num?)?.toInt() ?? 1920;
          final rawTags = (raw['tags']?.toString() ?? '').split(' ');
          final isLandscape = w > h;

          final sampleUrl = raw['sample_url']?.toString() ??
              'https://safebooru.org/images/$dir/$img';
          final previewUrl = raw['preview_url']?.toString() ??
              'https://safebooru.org/thumbnails/$dir/thumbnail_$hash.jpg';

          final cleanTags = rawTags
              .where((t) => t.isNotEmpty && !t.contains(':') && t.length > 2)
              .take(4)
              .map((t) => t.replaceAll('_', ' '))
              .toList();

          items.add(
            WallpaperItem(
              id: 'safebooru_$id',
              title: cleanTags.isNotEmpty ? cleanTags.first : 'SomeACG 精选壁纸 #$id',
              previewUrl: previewUrl,
              rawUrl: sampleUrl,
              width: w,
              height: h,
              tags: cleanTags,
              author: raw['owner']?.toString() ?? 'SomeACG 社区',
              resolution: isLandscape ? '4K 超清 · 宽屏' : '2K 超清 · 竖屏',
              likes: ((int.tryParse(id) ?? 100) % 800) + 120,
            ),
          );
        }
        return items;
      }
    }
    return [];
  }

  static List<WallpaperItem> _filterCurated({
    required String category,
    required String query,
  }) {
    var list = List<WallpaperItem>.from(_curatedWallpapers);
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((item) {
        return item.title.toLowerCase().contains(q) ||
            item.tags.any((t) => t.toLowerCase().contains(q)) ||
            item.author.toLowerCase().contains(q);
      }).toList();
    } else if (category == 'pc') {
      list = list.where((item) => item.width >= item.height).toList();
    } else if (category == 'mobile') {
      list = list.where((item) => item.height > item.width).toList();
    } else if (category == 'genshin') {
      list = list.where((item) => item.tags.any((t) => t.contains('原神'))).toList();
    } else if (category == 'starrail') {
      list = list.where((item) => item.tags.any((t) => t.contains('星穹铁道') || t.contains('星铁'))).toList();
    } else if (category == 'miku') {
      list = list.where((item) => item.tags.any((t) => t.contains('初音'))).toList();
    } else if (category == 'arknights') {
      list = list.where((item) => item.tags.any((t) => t.contains('明日方舟'))).toList();
    }
    return list;
  }
}
