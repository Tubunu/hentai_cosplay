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

  String _searchKeyword = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get pageSize => _pageSize;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchKeyword => _searchKeyword;
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

  void setSearchKeyword(String keyword) {
    _searchKeyword = keyword.trim();
    loadPage(1);
  }

  void clearSearch() {
    _searchKeyword = '';
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
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await HCApiService.fetchPageData(
        page: page,
        keyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
      );

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
      _errorMessage = '加载出错: $e';
    } finally {
      _isLoading = false;
      _selectedSlugs.clear();
      _isSelectionMode = false;
      notifyListeners();
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
