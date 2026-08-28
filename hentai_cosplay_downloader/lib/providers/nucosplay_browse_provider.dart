import 'package:flutter/foundation.dart';
import '../models/album_item.dart';
import '../services/nucosplay/nucosplay_api_service.dart';

class NucosplayBrowseProvider extends ChangeNotifier {
  List<AlbumItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _currentRequestId = 0;

  NuCosplayCategory _currentCategory = NuCosplayCategory.latest;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  NuCosplayCategory get currentCategory => _currentCategory;
  String? get searchKeyword => _searchKeyword;
  bool get isSearchMode => _searchKeyword != null && _searchKeyword!.isNotEmpty;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;
  List<AlbumItem> get selectedItems =>
      _items.where((item) => _selectedSlugs.contains(item.slug)).toList();

  NucosplayBrowseProvider() {
    loadPage(1);
  }

  void setSelectionMode(bool value) {
    _isSelectionMode = value;
    if (!value) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(AlbumItem item) {
    if (_selectedSlugs.contains(item.slug)) {
      _selectedSlugs.remove(item.slug);
      if (_selectedSlugs.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedSlugs.add(item.slug);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  bool isSelected(AlbumItem item) => _selectedSlugs.contains(item.slug);

  void selectAll() {
    for (final item in _items) {
      _selectedSlugs.add(item.slug);
    }
    _isSelectionMode = true;
    notifyListeners();
  }

  void deselectAll() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  Future<void> loadPage(int page) async {
    final requestId = ++_currentRequestId;
    _currentPage = page;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await NucosplayApiService.fetchPageData(
        page: page,
        category: _currentCategory,
        keyword: _searchKeyword,
      );

      if (requestId != _currentRequestId) return;

      if (response != null) {
        _items = response.items;
        _currentPage = response.page;
        _totalPages = response.totalPages;
        _totalItems = response.total;
        _selectedSlugs.clear();
        _isSelectionMode = false;
      } else {
        _errorMessage = '获取 NuCosplay 列表失败，请检查网络或配置代理';
      }
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = '请求错误: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void switchCategory(NuCosplayCategory category) {
    if (_currentCategory == category && _searchKeyword == null) return;
    _currentCategory = category;
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  void search(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }
    _searchKeyword = trimmed;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  void clearSearch() {
    if (_searchKeyword == null) return;
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  void nextPage() {
    if (_currentPage < _totalPages) {
      loadPage(_currentPage + 1);
    }
  }

  void prevPage() {
    if (_currentPage > 1) {
      loadPage(_currentPage - 1);
    }
  }

  Future<void> refresh() async {
    await loadPage(_currentPage);
  }
}
