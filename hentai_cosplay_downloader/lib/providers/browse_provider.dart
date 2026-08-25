import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../services/hc_api_service.dart';

class BrowseProvider extends ChangeNotifier {
  List<AlbumItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _pageSize = 32;

  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;
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

  BrowseCategory _category = BrowseCategory.latest;
  String _searchKeyword = '';
  String? _currentTag;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get pageSize => _pageSize;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BrowseCategory get category => _category;
  String get searchKeyword => _searchKeyword;
  String? get currentTag => _currentTag;
  bool get isTagActive => _currentTag != null && _currentTag!.isNotEmpty;
  bool get isSearchActive => _searchKeyword.isNotEmpty;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  List<AlbumItem> get selectedItems {
    return _items.where((it) {
      final key = it.slug.isNotEmpty ? it.slug : it.detailUrl;
      return _selectedSlugs.contains(key);
    }).toList();
  }

  BrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  void setCategory(BrowseCategory newCat) {
    _category = newCat;
    _searchKeyword = '';
    _currentTag = null;
    loadPage(1);
  }

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword.trim();
    _currentTag = null;
    loadPage(1);
  }

  void setTag(String tag) {
    _currentTag = tag.trim();
    _searchKeyword = '';
    loadPage(1);
  }

  void clearSearch() {
    _searchKeyword = '';
    loadPage(1);
  }

  void clearTag() {
    _currentTag = null;
    loadPage(1);
  }

  void resetToLatest() {
    _category = BrowseCategory.latest;
    _searchKeyword = '';
    _currentTag = null;
    loadPage(1);
  }

  void toggleSelectionMode([bool? force]) {
    _isSelectionMode = force ?? !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleAlbumSelection(AlbumItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    if (_selectedSlugs.contains(key)) {
      _selectedSlugs.remove(key);
      if (_selectedSlugs.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedSlugs.add(key);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  bool isAlbumSelected(AlbumItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    return _selectedSlugs.contains(key);
  }

  void selectAllCurrentPage() {
    for (final item in _items) {
      final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
      _selectedSlugs.add(key);
    }
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  Future<void> loadPage(int page) async {
    final currentReq = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await HCApiService.fetchPageData(
        category: _category,
        keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
        tag: _currentTag != null && _currentTag!.isNotEmpty ? _currentTag : null,
        page: page,
      );

      if (currentReq != _requestId || _disposed) return;

      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalItems = res.total;
        _pageSize = res.pageSize;
      } else {
        _errorMessage = '获取相册列表失败，请检查网络或在设置中配置代理。';
      }
    } catch (e) {
      if (currentReq != _requestId || _disposed) return;
      _errorMessage = '加载出错: $e';
    } finally {
      if (currentReq == _requestId && !_disposed) {
        _isLoading = false;
        _selectedSlugs.clear();
        _isSelectionMode = false;
        notifyListeners();
      }
    }
  }

  void nextPage() {
    if (_currentPage < _totalPages && !_isLoading) {
      loadPage(_currentPage + 1);
    }
  }

  void previousPage() {
    if (_currentPage > 1 && !_isLoading) {
      loadPage(_currentPage - 1);
    }
  }
}
