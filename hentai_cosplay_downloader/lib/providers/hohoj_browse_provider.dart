import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/hohoj/hohoj_api_service.dart';

class HohojBrowseProvider extends ChangeNotifier {
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

  HohojCategory _currentCategory = HohojCategory.all;
  HohojOrder _currentOrder = HohojOrder.popular;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  HohojCategory get currentCategory => _currentCategory;
  HohojOrder get currentOrder => _currentOrder;
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

  HohojBrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadPage(1);
    }
  }

  Future<void> setCategory(HohojCategory cat) async {
    if (_currentCategory == cat && _searchKeyword == null) return;
    _currentCategory = cat;
    _searchKeyword = null;
    clearSelection();
    await loadPage(1);
  }

  Future<void> setOrder(HohojOrder order) async {
    if (_currentOrder == order && _searchKeyword == null) return;
    _currentOrder = order;
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
      final pageData = await HohojApiService.fetchVideos(
        page: page,
        category: _currentCategory,
        order: _currentOrder,
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
