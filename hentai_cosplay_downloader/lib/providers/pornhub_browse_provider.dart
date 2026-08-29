import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/pornhub/pornhub_api_service.dart';

class PornhubBrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;

  PornhubSortOrder _currentSortOrder = PornhubSortOrder.hottest;
  PornhubCategoryItem _currentCategory = PornhubApiService.defaultCategories.first;
  String _searchQuery = '';
  bool _isSearchMode = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  PornhubSortOrder get currentSortOrder => _currentSortOrder;
  PornhubCategoryItem get currentCategory => _currentCategory;
  String get searchQuery => _searchQuery;
  bool get isSearchMode => _isSearchMode;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

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

  Future<void> loadPage(int page) async {
    _isLoading = true;
    _errorMessage = null;
    _currentPage = page;
    notifyListeners();

    try {
      final res = await PornhubApiService.fetchPageData(
        page: page,
        sortOrder: _currentSortOrder,
        category: _isSearchMode ? null : _currentCategory,
        keyword: _isSearchMode ? _searchQuery : null,
      );

      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages > 0 ? res.totalPages : page + 1;
        _selectedSlugs.clear();
        _isSelectionMode = false;
        if (_items.isEmpty) {
          _errorMessage = '未找到相关视频，请尝试切换类别或搜索词';
        }
      } else {
        _errorMessage = '获取 Pornhub 视频列表失败，请检查网络或代理设置';
      }
    } catch (e) {
      _errorMessage = '加载失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void switchSortOrder(PornhubSortOrder sortOrder) {
    if (_currentSortOrder == sortOrder && !_isSearchMode) return;
    _currentSortOrder = sortOrder;
    _currentPage = 1;
    loadPage(1);
  }

  void switchCategory(PornhubCategoryItem category) {
    if (_currentCategory.slug == category.slug && !_isSearchMode) return;
    _currentCategory = category;
    _isSearchMode = false;
    _searchQuery = '';
    _currentPage = 1;
    loadPage(1);
  }

  void search(String keyword) {
    final query = keyword.trim();
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    _searchQuery = query;
    _isSearchMode = true;
    _currentPage = 1;
    loadPage(1);
  }

  void clearSearch() {
    if (!_isSearchMode && _searchQuery.isEmpty) return;
    _isSearchMode = false;
    _searchQuery = '';
    _currentPage = 1;
    loadPage(1);
  }

  Future<void> refresh() async {
    await loadPage(_currentPage);
  }

  void prevPage() {
    if (_currentPage > 1) {
      loadPage(_currentPage - 1);
    }
  }

  void nextPage() {
    if (_currentPage < _totalPages) {
      loadPage(_currentPage + 1);
    }
  }
}
