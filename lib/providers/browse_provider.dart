import 'package:flutter/material.dart';
import '../models/pack_item.dart';
import '../services/api_service.dart';

class BrowseProvider extends ChangeNotifier {
  List<PackItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _pageSize = 12;

  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedPackIds = {};

  List<PackItem> get items {
    if (_searchQuery.trim().isEmpty) return _items;
    final query = _searchQuery.trim().toLowerCase();
    return _items.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.author.toLowerCase().contains(query);
    }).toList();
  }

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get pageSize => _pageSize;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedPackIds => _selectedPackIds;
  int get selectedCount => _selectedPackIds.length;

  List<PackItem> get selectedItems {
    return _items.where((it) {
      final key = it.id ?? it.title;
      return _selectedPackIds.contains(key);
    }).toList();
  }

  BrowseProvider() {
    loadPage(1);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleSelectionMode([bool? force]) {
    _isSelectionMode = force ?? !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedPackIds.clear();
    }
    notifyListeners();
  }

  void togglePackSelection(PackItem item) {
    final key = item.id ?? item.title;
    if (_selectedPackIds.contains(key)) {
      _selectedPackIds.remove(key);
      if (_selectedPackIds.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedPackIds.add(key);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  bool isPackSelected(PackItem item) {
    final key = item.id ?? item.title;
    return _selectedPackIds.contains(key);
  }

  void selectAllCurrentPage() {
    for (final item in items) {
      _selectedPackIds.add(item.id ?? item.title);
    }
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPackIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  Future<void> loadPage(int page) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.fetchPageData(page: page, pageSize: _pageSize);
      if (res != null) {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalItems = res.total;
        _pageSize = res.pageSize;
      } else {
        _errorMessage = '获取数据失败，请检查网络连接或稍后重试。';
      }
    } catch (e) {
      _errorMessage = '加载出错: $e';
    } finally {
      _isLoading = false;
      _selectedPackIds.clear();
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
