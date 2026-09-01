import 'package:flutter/material.dart';
import '../models/album_item.dart';
import '../services/mzt_api_service.dart';

class MztBrowseProvider extends ChangeNotifier {
  List<AlbumItem> _allItems = [];
  List<AlbumItem> _filteredItems = [];
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

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _pageSize = 12;

  String _searchQuery = '';

  // Selection mode for batch downloading (persisting selected objects across pagination)
  bool _isSelectionMode = false;
  final Map<String, AlbumItem> _selectedMap = {};

  List<AlbumItem> get items => _filteredItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  String get searchQuery => _searchQuery;

  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedMap.length;
  List<AlbumItem> get selectedItems => _selectedMap.values.toList();

  MztBrowseProvider({bool autoLoad = false}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  /// Load a specific page from MZT API
  Future<void> loadPage(int page) async {
    final currentReq = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await MztApiService.fetchPageData(
        page: page,
        pageSize: _pageSize,
      );

      if (currentReq != _requestId || _disposed) return;

      if (res != null) {
        _currentPage = res.page;
        _totalItems = res.total;
        _totalPages = res.totalPages;
        _allItems = res.items;
        _applyFilter();
        _isLoading = false;
      } else {
        _isLoading = false;
        _errorMessage = '获取妹子图数据失败，请检查网络连接或重试。';
      }
    } catch (e) {
      if (currentReq != _requestId || _disposed) return;
      _isLoading = false;
      _errorMessage = '加载出错: $e';
    }

    if (currentReq == _requestId && !_disposed) {
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentPage > 1 && !_isLoading) {
      loadPage(_currentPage - 1);
    }
  }

  void nextPage() {
    if (_currentPage < _totalPages && !_isLoading) {
      loadPage(_currentPage + 1);
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      final lower = _searchQuery.toLowerCase();
      _filteredItems = _allItems.where((item) {
        return item.title.toLowerCase().contains(lower) ||
            item.author.toLowerCase().contains(lower);
      }).toList();
    }
  }

  // --- Selection Mode Methods ---

  void toggleSelectionMode([bool? forceState]) {
    _isSelectionMode = forceState ?? !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedMap.clear();
    }
    notifyListeners();
  }

  bool isPackSelected(AlbumItem item) {
    return _selectedMap.containsKey(item.slug);
  }

  void togglePackSelection(AlbumItem item) {
    if (_selectedMap.containsKey(item.slug)) {
      _selectedMap.remove(item.slug);
    } else {
      _selectedMap[item.slug] = item;
    }
    notifyListeners();
  }

  void selectAllCurrentPage() {
    for (final item in _filteredItems) {
      _selectedMap[item.slug] = item;
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedMap.clear();
    _isSelectionMode = false;
    notifyListeners();
  }
}
