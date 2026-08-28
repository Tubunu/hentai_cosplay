import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../services/misskon/misskon_api_service.dart';

class MisskonBrowseProvider extends ChangeNotifier {
  List<AlbumItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

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

  MisskonCategory _category = MisskonCategory.latest;
  String _searchKeyword = '';
  String? _currentTag;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  MisskonCategory get category => _category;
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

  MisskonBrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  void setCategory(MisskonCategory newCat) {
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
    _category = MisskonCategory.latest;
    _searchKeyword = '';
    _currentTag = null;
    loadPage(1);
  }

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(AlbumItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    if (_selectedSlugs.contains(key)) {
      _selectedSlugs.remove(key);
    } else {
      _selectedSlugs.add(key);
    }
    notifyListeners();
  }

  void selectAll() {
    for (final item in _items) {
      final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
      _selectedSlugs.add(key);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    notifyListeners();
  }

  bool isSelected(AlbumItem item) {
    final key = item.slug.isNotEmpty ? item.slug : item.detailUrl;
    return _selectedSlugs.contains(key);
  }

  Future<void> loadPage(int page) async {
    final reqId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await MisskonApiService.fetchPageData(
        page: page,
        category: _category,
        tag: _currentTag,
        keyword: _searchKeyword,
      );

      if (_disposed || reqId != _requestId) return;

      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalItems = res.total;
        _errorMessage = null;
      } else {
        _errorMessage = '加载失败，请检查网络或代理设置';
      }
    } catch (e) {
      if (_disposed || reqId != _requestId) return;
      _errorMessage = '网络请求异常: $e';
    } finally {
      if (!_disposed && reqId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> nextPage() async {
    if (_currentPage < _totalPages && !_isLoading) {
      await loadPage(_currentPage + 1);
    }
  }

  Future<void> prevPage() async {
    if (_currentPage > 1 && !_isLoading) {
      await loadPage(_currentPage - 1);
    }
  }
}
