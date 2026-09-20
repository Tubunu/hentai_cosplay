import 'package:flutter/foundation.dart';
import '../models/album_item.dart';
import '../services/nsfwpub/nsfwpub_api_service.dart';

class NsfwpubBrowseProvider extends ChangeNotifier {
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

  List<AlbumItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _currentRequestId = 0;

  NsfwpubCategory _currentCategory = NsfwpubCategory.all;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<AlbumItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  NsfwpubCategory get currentCategory => _currentCategory;
  String? get searchKeyword => _searchKeyword;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  bool isSelected(AlbumItem item) => _selectedSlugs.contains(item.slug);

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

  void selectAll() {
    _selectedSlugs.addAll(_items.map((i) => i.slug));
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
      final response = await NsfwpubApiService.fetchPageData(
        page: page,
        category: _currentCategory,
        keyword: _searchKeyword,
      );

      if (_disposed || requestId != _currentRequestId) return;

      _items = response.items;
      _currentPage = response.currentPage;
      _totalPages = response.totalPages;
    } catch (e) {
      if (_disposed || requestId != _currentRequestId) return;
      _errorMessage = '获取 NSFWPub 图集失败: $e';
    } finally {
      if (!_disposed && requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void switchCategory(NsfwpubCategory category) {
    if (_currentCategory == category && _searchKeyword == null) return;
    _currentCategory = category;
    _searchKeyword = null;
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    loadPage(1);
  }

  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      _searchKeyword = null;
    } else {
      _searchKeyword = trimmed;
    }
    _currentPage = 1;
    _items = [];
    _selectedSlugs.clear();
    _isSelectionMode = false;
    await loadPage(1);
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
