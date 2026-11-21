import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/ygjgl/ygjgl_post_item.dart';
import '../models/ygjgl/ygjgl_vod_item.dart';
import '../services/app_logger.dart';
import '../services/ygjgl/ygjgl_api_service.dart';

class YgjglBrowseProvider extends ChangeNotifier {
  // 0: 点播, 1: 写真, 2: 电台
  int _activeSubTab = 0;
  int get activeSubTab => _activeSubTab;

  void setActiveSubTab(int index) {
    if (_activeSubTab == index) return;
    _activeSubTab = index;
    notifyListeners();
  }

  // ==========================================
  // 1. 点播 (VOD) 状态
  // ==========================================
  List<YgjglVodItem> _vodItems = [];
  bool _isVodLoading = false;
  String? _vodErrorMessage;
  int _vodCurrentPage = 1;
  int _vodTotalPages = 1;
  int _vodTotalCount = 0;
  String _vodKeyword = '';
  String? _vodSelectedRegion; // null: 全部, '国产', '日本', '免费区'
  String _vodSort = 'pub_desc'; // 'pub_desc' | 'pub_asc' | 'hot_recent' | 'hot_desc' | 'views_desc'
  String? _vodSelectedYear;
  String? _vodSelectedMonth;
  List<Map<String, dynamic>> _regions = [];
  List<String> _years = [];

  List<YgjglVodItem> get vodItems => _vodItems;
  bool get isVodLoading => _isVodLoading;
  String? get vodErrorMessage => _vodErrorMessage;
  int get vodCurrentPage => _vodCurrentPage;
  int get vodTotalPages => _vodTotalPages;
  int get vodTotalCount => _vodTotalCount;
  String get vodKeyword => _vodKeyword;
  String? get vodSelectedRegion => _vodSelectedRegion;
  String get vodSort => _vodSort;
  String? get vodSelectedYear => _vodSelectedYear;
  String? get vodSelectedMonth => _vodSelectedMonth;
  List<Map<String, dynamic>> get regions => _regions;
  List<String> get years => _years;

  Future<void> loadVodPage({int page = 1, bool reset = false}) async {
    if (_isVodLoading) return;
    _isVodLoading = true;
    _vodErrorMessage = null;
    if (reset) {
      _vodItems = [];
    }
    notifyListeners();

    try {
      final isFree = _vodSelectedRegion == '免费区';
      final regionTag = isFree ? null : _vodSelectedRegion;

      final res = await YgjglApiService.fetchVodList(
        page: page,
        size: 40,
        q: _vodKeyword,
        sort: _vodSort,
        tag: regionTag,
        freeOnly: isFree,
        year: _vodSelectedYear,
        month: _vodSelectedMonth,
      );

      final newItems = res['items'] as List<YgjglVodItem>? ?? [];
      final total = res['total'] as int? ?? 0;

      _vodItems = newItems;
      _vodTotalCount = total;
      _vodCurrentPage = page;
      _vodTotalPages = max(1, (total / 40).ceil());
    } catch (e, st) {
      _vodErrorMessage = '加载失败: $e';
      AppLogger.e('YgjglBrowseProvider', 'loadVodPage 失败: $e', e, st);
    } finally {
      _isVodLoading = false;
      notifyListeners();
    }
  }

  void setVodKeyword(String q) {
    if (_vodKeyword == q) return;
    _vodKeyword = q;
    loadVodPage(page: 1, reset: true);
  }

  void setVodRegion(String? r) {
    if (_vodSelectedRegion == r) return;
    _vodSelectedRegion = r;
    loadVodPage(page: 1, reset: true);
  }

  void setVodSort(String s) {
    if (_vodSort == s) return;
    _vodSort = s;
    loadVodPage(page: 1, reset: true);
  }

  void setVodDate(String? y, String? m) {
    if (_vodSelectedYear == y && _vodSelectedMonth == m) return;
    _vodSelectedYear = y;
    _vodSelectedMonth = m;
    loadVodPage(page: 1, reset: true);
  }

  void resetVodFilters() {
    _vodKeyword = '';
    _vodSelectedRegion = null;
    _vodSort = 'pub_desc';
    _vodSelectedYear = null;
    _vodSelectedMonth = null;
    loadVodPage(page: 1, reset: true);
  }

  Future<void> loadVodMeta() async {
    try {
      final regs = await YgjglApiService.fetchRegions();
      if (regs.isNotEmpty) {
        _regions = regs;
      }
      final facets = await YgjglApiService.fetchFacets();
      if (facets['years'] is List) {
        _years = (facets['years'] as List).map((e) => e.toString()).toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  // ==========================================
  // 2. 写真 (Image) 状态
  // ==========================================
  List<YgjglPostItem> _imageItems = [];
  List<YgjglPostItem> _imageRankItems = [];
  bool _isImageLoading = false;
  String? _imageErrorMessage;
  int _imageCurrentPage = 1;
  int _imageTotalPages = 1;
  int _imageTotalCount = 0;
  String _imageKeyword = '';
  String? _imageSelectedTag;
  int _imageSelectedSeries = 0;
  String _imageRange = 'all'; // 'all', 'today', 'week', 'month'
  String _imageSort = 'new'; // 'new', 'hot', 'views', 'images'
  bool _isImageRankView = false;
  String _imageRankWindow = 'week';
  List<Map<String, dynamic>> _imageTags = [];
  List<Map<String, dynamic>> _imageSeries = [];

  List<YgjglPostItem> get imageItems => _imageItems;
  List<YgjglPostItem> get imageRankItems => _imageRankItems;
  bool get isImageLoading => _isImageLoading;
  String? get imageErrorMessage => _imageErrorMessage;
  int get imageCurrentPage => _imageCurrentPage;
  int get imageTotalPages => _imageTotalPages;
  int get imageTotalCount => _imageTotalCount;
  String get imageKeyword => _imageKeyword;
  String? get imageSelectedTag => _imageSelectedTag;
  int get imageSelectedSeries => _imageSelectedSeries;
  String get imageRange => _imageRange;
  String get imageSort => _imageSort;
  bool get isImageRankView => _isImageRankView;
  String get imageRankWindow => _imageRankWindow;
  List<Map<String, dynamic>> get imageTags => _imageTags;
  List<Map<String, dynamic>> get imageSeries => _imageSeries;

  Future<void> loadImagePage({int page = 1, bool reset = false}) async {
    if (_isImageRankView) {
      return loadImageRank();
    }

    if (_isImageLoading) return;
    _isImageLoading = true;
    _imageErrorMessage = null;
    if (reset) {
      _imageItems = [];
    }
    notifyListeners();

    try {
      final res = await YgjglApiService.fetchPostList(
        kind: 'image',
        page: page,
        size: 24,
        q: _imageKeyword,
        tag: _imageSelectedTag,
        series: _imageSelectedSeries,
        range: _imageRange,
        sort: _imageSort,
      );

      final items = res['items'] as List<YgjglPostItem>? ?? [];
      final total = res['total'] as int? ?? 0;

      _imageItems = items;
      _imageTotalCount = total;
      _imageCurrentPage = page;
      _imageTotalPages = max(1, (total / 24).ceil());
    } catch (e, st) {
      _imageErrorMessage = '加载失败: $e';
      AppLogger.e('YgjglBrowseProvider', 'loadImagePage 失败: $e', e, st);
    } finally {
      _isImageLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadImageRank() async {
    if (_isImageLoading) return;
    _isImageLoading = true;
    _imageErrorMessage = null;
    notifyListeners();

    try {
      final items = await YgjglApiService.fetchPostRank(
        kind: 'image',
        window: _imageRankWindow,
        limit: 30,
      );
      _imageRankItems = items;
    } catch (e, st) {
      _imageErrorMessage = '加载排行榜失败: $e';
      AppLogger.e('YgjglBrowseProvider', 'loadImageRank 失败: $e', e, st);
    } finally {
      _isImageLoading = false;
      notifyListeners();
    }
  }

  void toggleImageRankView() {
    _isImageRankView = !_isImageRankView;
    if (_isImageRankView) {
      loadImageRank();
    } else {
      loadImagePage(page: 1, reset: true);
    }
  }

  void setImageRankWindow(String w) {
    if (_imageRankWindow == w) return;
    _imageRankWindow = w;
    loadImageRank();
  }

  void setImageKeyword(String q) {
    if (_imageKeyword == q) return;
    _imageKeyword = q;
    _isImageRankView = false;
    loadImagePage(page: 1, reset: true);
  }

  void setImageTag(String? t) {
    if (_imageSelectedTag == t) {
      _imageSelectedTag = null; // Toggle off
    } else {
      _imageSelectedTag = t;
    }
    _isImageRankView = false;
    loadImagePage(page: 1, reset: true);
  }

  void setImageSeries(int s) {
    if (_imageSelectedSeries == s) return;
    _imageSelectedSeries = s;
    _isImageRankView = false;
    loadImagePage(page: 1, reset: true);
  }

  void setImageRange(String r) {
    if (_imageRange == r) return;
    _imageRange = r;
    _isImageRankView = false;
    loadImagePage(page: 1, reset: true);
  }

  void setImageSort(String s) {
    if (_imageSort == s) return;
    _imageSort = s;
    _isImageRankView = false;
    loadImagePage(page: 1, reset: true);
  }

  void resetImageFilters() {
    _imageKeyword = '';
    _imageSelectedTag = null;
    _imageSelectedSeries = 0;
    _imageRange = 'all';
    _imageSort = 'new';
    _isImageRankView = false;
    loadImagePage(page: 1, reset: true);
  }

  Future<void> loadImageMeta() async {
    try {
      final tags = await YgjglApiService.fetchPostTags(kind: 'image');
      if (tags.isNotEmpty) _imageTags = tags;
      final series = await YgjglApiService.fetchPostSeries(kind: 'image');
      if (series.isNotEmpty) _imageSeries = series;
      notifyListeners();
    } catch (_) {}
  }

  // ==========================================
  // 3. 电台 (Audio) 状态
  // ==========================================
  List<YgjglPostItem> _audioItems = [];
  List<YgjglPostItem> _audioRankItems = [];
  bool _isAudioLoading = false;
  String? _audioErrorMessage;
  int _audioCurrentPage = 1;
  int _audioTotalPages = 1;
  int _audioTotalCount = 0;
  String _audioKeyword = '';
  String? _audioSelectedTag;
  String _audioRange = 'all';
  String _audioSort = 'new';
  bool _isAudioRankView = false;
  String _audioRankWindow = 'week';
  List<Map<String, dynamic>> _audioTags = [];

  List<YgjglPostItem> get audioItems => _audioItems;
  List<YgjglPostItem> get audioRankItems => _audioRankItems;
  bool get isAudioLoading => _isAudioLoading;
  String? get audioErrorMessage => _audioErrorMessage;
  int get audioCurrentPage => _audioCurrentPage;
  int get audioTotalPages => _audioTotalPages;
  int get audioTotalCount => _audioTotalCount;
  String get audioKeyword => _audioKeyword;
  String? get audioSelectedTag => _audioSelectedTag;
  String get audioRange => _audioRange;
  String get audioSort => _audioSort;
  bool get isAudioRankView => _isAudioRankView;
  String get audioRankWindow => _audioRankWindow;
  List<Map<String, dynamic>> get audioTags => _audioTags;

  Future<void> loadAudioPage({int page = 1, bool reset = false}) async {
    if (_isAudioRankView) {
      return loadAudioRank();
    }

    if (_isAudioLoading) return;
    _isAudioLoading = true;
    _audioErrorMessage = null;
    if (reset) {
      _audioItems = [];
    }
    notifyListeners();

    try {
      final res = await YgjglApiService.fetchPostList(
        kind: 'audio',
        page: page,
        size: 24,
        q: _audioKeyword,
        tag: _audioSelectedTag,
        range: _audioRange,
        sort: _audioSort,
      );

      final items = res['items'] as List<YgjglPostItem>? ?? [];
      final total = res['total'] as int? ?? 0;

      _audioItems = items;
      _audioTotalCount = total;
      _audioCurrentPage = page;
      _audioTotalPages = max(1, (total / 24).ceil());
    } catch (e, st) {
      _audioErrorMessage = '加载失败: $e';
      AppLogger.e('YgjglBrowseProvider', 'loadAudioPage 失败: $e', e, st);
    } finally {
      _isAudioLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAudioRank() async {
    if (_isAudioLoading) return;
    _isAudioLoading = true;
    _audioErrorMessage = null;
    notifyListeners();

    try {
      final items = await YgjglApiService.fetchPostRank(
        kind: 'audio',
        window: _audioRankWindow,
        limit: 30,
      );
      _audioRankItems = items;
    } catch (e, st) {
      _audioErrorMessage = '加载排行榜失败: $e';
      AppLogger.e('YgjglBrowseProvider', 'loadAudioRank 失败: $e', e, st);
    } finally {
      _isAudioLoading = false;
      notifyListeners();
    }
  }

  void toggleAudioRankView() {
    _isAudioRankView = !_isAudioRankView;
    if (_isAudioRankView) {
      loadAudioRank();
    } else {
      loadAudioPage(page: 1, reset: true);
    }
  }

  void setAudioRankWindow(String w) {
    if (_audioRankWindow == w) return;
    _audioRankWindow = w;
    loadAudioRank();
  }

  void setAudioKeyword(String q) {
    if (_audioKeyword == q) return;
    _audioKeyword = q;
    _isAudioRankView = false;
    loadAudioPage(page: 1, reset: true);
  }

  void setAudioTag(String? t) {
    if (_audioSelectedTag == t) {
      _audioSelectedTag = null; // Toggle off
    } else {
      _audioSelectedTag = t;
    }
    _isAudioRankView = false;
    loadAudioPage(page: 1, reset: true);
  }

  void setAudioRange(String r) {
    if (_audioRange == r) return;
    _audioRange = r;
    _isAudioRankView = false;
    loadAudioPage(page: 1, reset: true);
  }

  void setAudioSort(String s) {
    if (_audioSort == s) return;
    _audioSort = s;
    _isAudioRankView = false;
    loadAudioPage(page: 1, reset: true);
  }

  void resetAudioFilters() {
    _audioKeyword = '';
    _audioSelectedTag = null;
    _audioRange = 'all';
    _audioSort = 'new';
    _isAudioRankView = false;
    loadAudioPage(page: 1, reset: true);
  }

  Future<void> loadAudioMeta() async {
    try {
      final tags = await YgjglApiService.fetchPostTags(kind: 'audio');
      if (tags.isNotEmpty) _audioTags = tags;
      notifyListeners();
    } catch (_) {}
  }
}
