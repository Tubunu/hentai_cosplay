import 'package:flutter/foundation.dart';
import '../../models/video_item.dart';
import '../../services/twitter_rankings/twitter_ranking_api_service.dart';
import '../../services/twitter_rankings/twitter_site_config.dart';

class TwitterSiteState {
  final String siteId;
  String currentRange;
  String currentSort;
  String? searchKeyword;

  List<VideoItem> items;
  int page;
  int totalPages;
  String? nextCursor;
  bool hasMore;

  bool isLoaded;
  bool isLoading;
  String? errorMessage;

  TwitterSiteState({
    required this.siteId,
    required this.currentRange,
    required this.currentSort,
    this.searchKeyword,
    List<VideoItem>? items,
    this.page = 1,
    this.totalPages = 1,
    this.nextCursor,
    this.hasMore = true,
    this.isLoaded = false,
    this.isLoading = false,
    this.errorMessage,
  }) : items = items ?? [];
}

class TwitterBrowseProvider extends ChangeNotifier {
  TwitterSiteConfig _currentSite = TwitterSiteConfig.defaultSite;
  final Map<String, TwitterSiteState> _siteStates = {};

  bool _isLoadingMore = false;

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  TwitterBrowseProvider({bool autoLoad = false}) {
    if (autoLoad) {
      fetchData();
    }
  }

  TwitterSiteState _getOrCreateState(TwitterSiteConfig site) {
    return _siteStates.putIfAbsent(site.id, () {
      final defaultRange = site.rangeOptions.isNotEmpty ? site.rangeOptions.first.id : 'daily';
      final defaultSort = site.sortOptions.isNotEmpty ? site.sortOptions.first.id : 'favorite';
      return TwitterSiteState(
        siteId: site.id,
        currentRange: defaultRange,
        currentSort: defaultSort,
      );
    });
  }

  TwitterSiteState get currentState => _getOrCreateState(_currentSite);

  TwitterSiteConfig get currentSite => _currentSite;
  String get currentRange => currentState.currentRange;
  String get currentSort => currentState.currentSort;
  String? get searchKeyword => currentState.searchKeyword;

  List<VideoItem> get items => currentState.items;
  int get page => currentState.page;
  int get totalPages => currentState.totalPages;
  bool get hasMore => currentState.hasMore;
  bool get isLoading => currentState.isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => currentState.errorMessage;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  List<VideoItem> get selectedItems =>
      items.where((i) => _selectedSlugs.contains(i.slug)).toList();

  /// Change active Twitter ranking site (with instant memory cache)
  void setSite(TwitterSiteConfig site) {
    if (_currentSite.id == site.id) return;
    _currentSite = site;
    clearSelection();

    final state = _getOrCreateState(site);
    if (!state.isLoaded) {
      fetchData();
    } else {
      notifyListeners();
    }
  }

  /// Change ranking range (e.g. 24h, weekly, monthly)
  void setRange(String range) {
    if (currentState.currentRange == range) return;
    currentState.currentRange = range;
    fetchData(refresh: true);
  }

  /// Change sorting metric (e.g. likes, views, new)
  void setSort(String sort) {
    if (currentState.currentSort == sort) return;
    currentState.currentSort = sort;
    fetchData(refresh: true);
  }

  /// Search keyword
  void search(String? keyword) {
    currentState.searchKeyword = (keyword != null && keyword.trim().isNotEmpty) ? keyword.trim() : null;
    fetchData(refresh: true);
  }

  /// Fetch first page or refresh for the CURRENT site
  Future<void> fetchData({bool refresh = false}) async {
    final state = currentState;
    if (state.isLoading) return;

    state.isLoading = true;
    state.errorMessage = null;
    if (refresh) {
      state.page = 1;
      state.nextCursor = null;
      state.hasMore = true;
    }
    notifyListeners();

    try {
      final res = await TwitterRankingApiService.fetchPageData(
        site: _currentSite,
        range: state.currentRange,
        sort: state.currentSort,
        page: 1,
        cursor: null,
        keyword: state.searchKeyword,
      );

      if (res != null) {
        state.items = res.items;
        state.page = res.currentPage;
        state.totalPages = res.totalPages;
        state.nextCursor = res.nextCursor;
        state.hasMore = res.hasMore;
        state.isLoaded = true;
      } else {
        state.items = [];
        state.hasMore = false;
        state.isLoaded = true;
      }
    } catch (e) {
      state.errorMessage = '获取 [${_currentSite.name}] 列表失败: $e';
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page for the current site
  Future<void> loadMore() async {
    final state = currentState;
    if (state.isLoading || _isLoadingMore || !state.hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = state.page + 1;
      final res = await TwitterRankingApiService.fetchPageData(
        site: _currentSite,
        range: state.currentRange,
        sort: state.currentSort,
        page: nextPage,
        cursor: state.nextCursor,
        keyword: state.searchKeyword,
      );

      if (res != null && res.items.isNotEmpty) {
        // Prevent duplicate items within the site
        final existingSlugs = state.items.map((e) => e.slug).toSet();
        for (final item in res.items) {
          if (!existingSlugs.contains(item.slug)) {
            state.items.add(item);
          }
        }
        state.page = res.currentPage;
        state.totalPages = res.totalPages;
        state.nextCursor = res.nextCursor;
        state.hasMore = res.hasMore;
      } else {
        state.hasMore = false;
      }
    } catch (e) {
      debugPrint('Twitter loadMore error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Jump directly to specific page (for paginated sites)
  Future<void> jumpToPage(int targetPage) async {
    final state = currentState;
    if (state.isLoading || targetPage < 1) return;

    state.isLoading = true;
    state.errorMessage = null;
    state.page = targetPage;
    state.nextCursor = targetPage.toString();
    notifyListeners();

    try {
      final res = await TwitterRankingApiService.fetchPageData(
        site: _currentSite,
        range: state.currentRange,
        sort: state.currentSort,
        page: targetPage,
        cursor: targetPage.toString(),
        keyword: state.searchKeyword,
      );

      if (res != null) {
        state.items = res.items;
        state.page = res.currentPage;
        state.totalPages = res.totalPages;
        state.nextCursor = res.nextCursor;
        state.hasMore = res.hasMore;
        state.isLoaded = true;
      }
    } catch (e) {
      state.errorMessage = '跳转至第 $targetPage 页失败: $e';
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }

  /// Resolve video detail / direct stream URL
  Future<VideoItem> resolveVideoDetail(VideoItem item) async {
    final updated = await TwitterRankingApiService.resolveVideoDetail(_currentSite, item);
    final idx = currentState.items.indexWhere((i) => i.slug == item.slug);
    if (idx != -1) {
      currentState.items[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  // ================= Selection Mode =================
  void toggleSelectionMode([bool? enable]) {
    _isSelectionMode = enable ?? !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(String slug) {
    if (_selectedSlugs.contains(slug)) {
      _selectedSlugs.remove(slug);
    } else {
      _selectedSlugs.add(slug);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedSlugs.addAll(items.map((e) => e.slug));
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
