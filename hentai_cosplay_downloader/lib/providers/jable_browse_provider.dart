import 'package:flutter/material.dart';
import '../models/jable_video_item.dart';
import '../services/jable/scrapers/base_scraper.dart';
import '../services/jable/scrapers/jable_scraper.dart';
import '../services/jable/scrapers/missav_scraper.dart';
import '../services/jable/scrapers/supjav_scraper.dart';

class SiteBrowseState {
  final List<CategoryModel> categories = [];
  final List<VideoCardModel> videos = [];
  final Set<VideoCardModel> selectedBatchVideos = {};
  String? selectedCategoryUrl;
  String searchQuery = '';
  String selectedSort = '';
  int currentPage = 1;
  bool loadingCategories = false;
  bool loadingVideos = false;
  String? errorMessage;
  bool isInitialized = false;
}

class JableBrowseProvider extends ChangeNotifier {
  int _currentSiteIndex = 0; // 0: JableTV, 1: MissAV, 2: SupJav
  final List<BaseScraper> _scrapers = [
    JableScraper(),
    MissAVScraper(),
    SupJavScraper(),
  ];

  final List<SiteBrowseState> _siteStates = [
    SiteBrowseState(),
    SiteBrowseState(),
    SiteBrowseState(),
  ];

  bool _isBatchMode = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  int get currentSiteIndex => _currentSiteIndex;
  BaseScraper get currentScraper => _scrapers[_currentSiteIndex];
  SiteBrowseState get currentState => _siteStates[_currentSiteIndex];

  SiteBrowseState getStateFor(int siteIndex) =>
      _siteStates[siteIndex.clamp(0, _siteStates.length - 1)];
  BaseScraper getScraperFor(int siteIndex) =>
      _scrapers[siteIndex.clamp(0, _scrapers.length - 1)];

  List<CategoryModel> get categories => List.unmodifiable(currentState.categories);
  List<VideoCardModel> get videos => List.unmodifiable(currentState.videos);
  Set<VideoCardModel> get selectedBatchVideos => currentState.selectedBatchVideos;
  String? get selectedCategoryUrl => currentState.selectedCategoryUrl;
  String get searchQuery => currentState.searchQuery;
  String get selectedSort => currentState.selectedSort;
  int get currentPage => currentState.currentPage;
  bool get loadingCategories => currentState.loadingCategories;
  bool get loadingVideos => currentState.loadingVideos;
  String? get errorMessage => currentState.errorMessage;
  bool get isBatchMode => _isBatchMode;

  JableBrowseProvider({bool autoLoad = false}) {
    if (autoLoad) {
      loadCategories();
    }
  }

  void switchSite(int index) {
    if (_currentSiteIndex == index || index < 0 || index >= _scrapers.length) return;
    _currentSiteIndex = index;
    _isBatchMode = false;
    notifyListeners();

    // Only load if this site has not been loaded yet
    final state = _siteStates[index];
    if (!state.isInitialized && state.categories.isEmpty && !state.loadingCategories) {
      loadCategories(siteIndex: index);
    }
  }

  Future<void> loadCategories({int? siteIndex, bool forceRefresh = false}) async {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    final scraper = _scrapers[targetIndex];
    if (state.loadingCategories) return;

    state.loadingCategories = true;
    state.errorMessage = null;
    notifyListeners();

    try {
      final cats = await scraper.fetchCategories();
      if (_disposed) return;
      state.categories.clear();
      state.categories.addAll(cats);
      state.isInitialized = true;
      if (state.categories.isNotEmpty && state.selectedCategoryUrl == null) {
        state.selectedCategoryUrl = state.categories.first.url;
      }
      state.loadingCategories = false;
      notifyListeners();

      if (state.selectedCategoryUrl != null && (state.videos.isEmpty || forceRefresh)) {
        loadVideos(siteIndex: targetIndex);
      }
    } catch (e) {
      if (_disposed) return;
      state.errorMessage = "获取分类列表失败: $e";
      state.loadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> loadVideos({int? siteIndex}) async {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    final scraper = _scrapers[targetIndex];
    if (state.loadingVideos) return;
    state.loadingVideos = true;
    state.errorMessage = null;
    state.selectedBatchVideos.clear();
    notifyListeners();

    try {
      List<VideoCardModel> videosList;
      if (state.searchQuery.isNotEmpty) {
        if (scraper.siteName == 'JableTV') {
          final encoded = Uri.encodeComponent(state.searchQuery);
          final searchUrl = scraper.buildPageUrl("${scraper.urlRoot}/search/$encoded/", state.currentPage);
          videosList = await scraper.fetchPage(searchUrl);
        } else if (scraper.siteName == 'MissAV') {
          final encoded = Uri.encodeComponent(state.searchQuery);
          final searchUrl = scraper.buildPageUrl(_applySort(state, "${scraper.urlRoot}/search/$encoded"), state.currentPage);
          videosList = await scraper.fetchPage(searchUrl);
        } else if (scraper.siteName == 'SupJav') {
          final encoded = Uri.encodeComponent(state.searchQuery);
          final searchUrl = scraper.buildPageUrl("${scraper.urlRoot}/zh/?s=$encoded", state.currentPage);
          videosList = await scraper.fetchPage(searchUrl);
        } else {
          videosList = await scraper.search(state.searchQuery);
        }
      } else if (state.selectedCategoryUrl != null) {
        final paginatedUrl = scraper.buildPageUrl(_applySort(state, state.selectedCategoryUrl!), state.currentPage);
        videosList = await scraper.fetchPage(paginatedUrl);
      } else {
        videosList = [];
      }

      if (_disposed) return;
      state.videos.clear();
      state.videos.addAll(videosList);
      state.loadingVideos = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      state.videos.clear();
      state.errorMessage = e.toString();
      state.loadingVideos = false;
      notifyListeners();
    }
  }

  String _applySort(SiteBrowseState state, String baseUrl) {
    if (state.selectedSort.isEmpty) return baseUrl;
    final uri = Uri.parse(baseUrl);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['sort'] = state.selectedSort;
    return uri.replace(queryParameters: qp).toString();
  }

  void selectCategory(String url, {int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    if (state.selectedCategoryUrl == url && state.searchQuery.isEmpty) return;
    state.selectedCategoryUrl = url;
    state.searchQuery = '';
    state.selectedSort = '';
    state.currentPage = 1;
    _isBatchMode = false;
    state.selectedBatchVideos.clear();
    loadVideos(siteIndex: targetIndex);
  }

  void setSort(String sortVal, {int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    if (state.selectedSort == sortVal) return;
    state.selectedSort = sortVal;
    state.currentPage = 1;
    state.selectedBatchVideos.clear();
    loadVideos(siteIndex: targetIndex);
  }

  void search(String query, {int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    state.searchQuery = query.trim();
    state.currentPage = 1;
    state.selectedBatchVideos.clear();
    loadVideos(siteIndex: targetIndex);
  }

  void gotoPage(int page, {int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    if (page < 1 || page == state.currentPage) return;
    state.currentPage = page;
    state.selectedBatchVideos.clear();
    loadVideos(siteIndex: targetIndex);
  }

  void toggleBatchMode({int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    _isBatchMode = !_isBatchMode;
    if (!_isBatchMode) {
      state.selectedBatchVideos.clear();
    }
    notifyListeners();
  }

  void toggleVideoSelection(VideoCardModel video, {int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    if (state.selectedBatchVideos.contains(video)) {
      state.selectedBatchVideos.remove(video);
    } else {
      state.selectedBatchVideos.add(video);
    }
    notifyListeners();
  }

  void selectAllVideos({int? siteIndex}) {
    final targetIndex = siteIndex ?? _currentSiteIndex;
    final state = _siteStates[targetIndex];
    if (state.selectedBatchVideos.length == state.videos.length) {
      state.selectedBatchVideos.clear();
    } else {
      state.selectedBatchVideos.addAll(state.videos);
    }
    notifyListeners();
  }
}
