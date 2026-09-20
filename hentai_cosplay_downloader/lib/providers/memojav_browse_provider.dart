import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/memojav/memojav_api_service.dart';

class MemojavBrowseProvider extends ChangeNotifier {
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

  List<VideoItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _currentRequestId = 0;

  MemojavCategory _currentCategory = MemojavCategory.best;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  MemojavCategory get currentCategory => _currentCategory;
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
    _selectedSlugs.addAll(_items.map((e) => e.slug));
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedSlugs.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  List<VideoItem> getSelectedItems() {
    return _items.where((e) => _selectedSlugs.contains(e.slug)).toList();
  }

  MemojavBrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  Future<void> setCategory(MemojavCategory cat) async {
    if (_currentCategory == cat && _searchKeyword == null) return;
    _currentCategory = cat;
    _searchKeyword = null;
    clearSelection();
    await loadPage(1);
  }

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      clearSearch();
      return;
    }
    _searchKeyword = keyword.trim();
    clearSelection();
    await loadPage(1);
  }

  Future<void> clearSearch() async {
    _searchKeyword = null;
    clearSelection();
    await loadPage(1);
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

  Future<void> refresh() async {
    await loadPage(_currentPage);
  }

  Future<void> loadPage(int page) async {
    final requestId = ++_currentRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final pageData = await MemojavApiService.fetchVideos(
        page: page,
        category: _currentCategory,
        keyword: _searchKeyword,
      );

      if (requestId != _currentRequestId) return;

      _items = pageData.items;
      _currentPage = pageData.currentPage;
      _totalPages = pageData.totalPages;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
