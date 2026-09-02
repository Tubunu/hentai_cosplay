import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/xvideos/xvideos_api_service.dart';

class XVideosBrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;

  // Mode for All Categories
  XVideosMainMode _mainMode = XVideosMainMode.latest;
  String _selectedMonth = XVideosApiService.getDefaultBestMonth();

  // Selected Category
  XVideosCategoryItem _currentCategory = XVideosApiService.defaultCategories.first;

  // SubSort for Category / Search
  XVideosSubSort _subSort = XVideosSubSort.none;

  // Search state
  String _searchQuery = '';
  bool _isSearchMode = false;

  // Multiselect state
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  XVideosMainMode get mainMode => _mainMode;
  String get selectedMonth => _selectedMonth;
  XVideosCategoryItem get currentCategory => _currentCategory;
  XVideosSubSort get subSort => _subSort;

  String get searchQuery => _searchQuery;
  bool get isSearchMode => _isSearchMode;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  bool get isCategoryOrSearchActive => _isSearchMode || !_currentCategory.isAll;

  List<VideoItem> get selectedItems =>
      _items.where((i) => _selectedSlugs.contains(i.slug)).toList();

  bool isSelected(VideoItem item) => _selectedSlugs.contains(item.slug);

  void setSelectionMode(bool val) {
    _isSelectionMode = val;
    if (!val) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleSelect(VideoItem item) {
    if (_selectedSlugs.contains(item.slug)) {
      _selectedSlugs.remove(item.slug);
    } else {
      _selectedSlugs.add(item.slug);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedSlugs.addAll(_items.map((e) => e.slug));
    notifyListeners();
  }

  void deselectAll() {
    _selectedSlugs.clear();
    notifyListeners();
  }

  Future<void> loadPage(int page, {bool clearItems = false}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    if (clearItems) {
      _items = [];
    }
    notifyListeners();

    try {
      final res = await XVideosApiService.fetchPageData(
        page: page,
        mainMode: _mainMode,
        selectedMonth: _selectedMonth,
        category: _isSearchMode ? null : _currentCategory,
        subSort: _subSort,
        keyword: _isSearchMode ? _searchQuery : null,
      );

      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages > 0 ? res.totalPages : page + 1;
        _selectedSlugs.clear();
        _isSelectionMode = false;
        if (_items.isEmpty) {
          _errorMessage = '未找到相关视频，请尝试切换类别、月份或搜索词';
        }
      } else {
        _errorMessage = '获取 XVideos 视频列表失败，请检查网络或代理设置';
      }
    } catch (e) {
      _errorMessage = '加载失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switch between "最新发布" and "最佳影片" (when on All Categories)
  void switchMainMode(XVideosMainMode mode) {
    if (_mainMode == mode && !_isSearchMode && _currentCategory.isAll) return;
    _mainMode = mode;
    _isSearchMode = false;
    _searchQuery = '';
    _currentCategory = XVideosApiService.defaultCategories.first;
    _subSort = XVideosSubSort.none;
    _currentPage = 1;
    loadPage(1, clearItems: true);
  }

  /// Change month for "最佳影片"
  void switchMonth(String month) {
    _selectedMonth = month;
    _mainMode = XVideosMainMode.best;
    _isSearchMode = false;
    _searchQuery = '';
    _currentCategory = XVideosApiService.defaultCategories.first;
    _subSort = XVideosSubSort.none;
    _currentPage = 1;
    loadPage(1, clearItems: true);
  }

  /// Switch category
  void switchCategory(XVideosCategoryItem category) {
    _currentCategory = category;
    _isSearchMode = false;
    _searchQuery = '';
    _subSort = XVideosSubSort.none;
    _currentPage = 1;
    loadPage(1, clearItems: true);
  }

  /// Switch sub-sorting mode (默认, 最新, 评级, 观看次数, 随机)
  void switchSubSort(XVideosSubSort sort) {
    if (_subSort == sort) return;
    _subSort = sort;
    _currentPage = 1;
    loadPage(1, clearItems: true);
  }

  /// Search keyword
  void search(String keyword) {
    final query = keyword.trim();
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    _searchQuery = query;
    _isSearchMode = true;
    _subSort = XVideosSubSort.none;
    _currentPage = 1;
    loadPage(1, clearItems: true);
  }

  /// Clear search and return to current category or main mode
  void clearSearch() {
    _isSearchMode = false;
    _searchQuery = '';
    _subSort = XVideosSubSort.none;
    _currentPage = 1;
    loadPage(1, clearItems: true);
  }

  Future<void> refresh() async {
    await loadPage(_currentPage, clearItems: false);
  }

  void prevPage() {
    if (_currentPage > 1) {
      loadPage(_currentPage - 1, clearItems: true);
    }
  }

  void nextPage() {
    if (_currentPage < _totalPages) {
      loadPage(_currentPage + 1, clearItems: true);
    }
  }
}
