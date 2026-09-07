import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/thothub/thothub_api_service.dart';

class ThothubBrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _currentRequestId = 0;

  ThothubCategory _currentCategory = ThothubCategory.latest;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  ThothubCategory get currentCategory => _currentCategory;
  String? get searchKeyword => _searchKeyword;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;

  bool isSelected(VideoItem item) => _selectedSlugs.contains(item.slug);

  void setSelectionMode(bool value) {
    _isSelectionMode = value;
    if (!value) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  void toggleItemSelection(VideoItem item) {
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
      final response = await ThothubApiService.fetchPageData(
        page: page,
        category: _currentCategory,
        keyword: _searchKeyword,
      );

      if (requestId != _currentRequestId) return;

      _items = response.items;
      _currentPage = response.currentPage;
      _totalPages = response.totalPages;
      _selectedSlugs.clear();
      _isSelectionMode = false;
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _errorMessage = '获取 Thothub 视频失败: $e';
    } finally {
      if (requestId == _currentRequestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void switchCategory(ThothubCategory category) {
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
