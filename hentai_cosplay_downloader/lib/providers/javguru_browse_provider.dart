import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/javguru/javguru_api_service.dart';

class JavguruBrowseProvider extends ChangeNotifier {
  List<VideoItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _currentRequestId = 0;

  JavguruCategory _currentCategory = JavguruCategory.all;
  String? _searchKeyword;

  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  List<VideoItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  JavguruCategory get currentCategory => _currentCategory;
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

  List<VideoItem> get selectedItems {
    return _items.where((item) => _selectedSlugs.contains(item.slug)).toList();
  }

  JavguruBrowseProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadVideos();
    }
  }

  Future<void> loadVideos({int page = 1}) async {
    final requestId = ++_currentRequestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await JavguruApiService.fetchVideos(
        page: page,
        category: _currentCategory,
        keyword: _searchKeyword,
      );

      if (requestId != _currentRequestId) return;

      _items = data.items;
      _currentPage = data.currentPage;
      _totalPages = data.totalPages;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (requestId != _currentRequestId) return;
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> setCategory(JavguruCategory category) async {
    if (_currentCategory == category && _searchKeyword == null) return;
    _currentCategory = category;
    _searchKeyword = null;
    _selectedSlugs.clear();
    _isSelectionMode = false;
    await loadVideos(page: 1);
  }

  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }
    _searchKeyword = trimmed;
    _selectedSlugs.clear();
    _isSelectionMode = false;
    await loadVideos(page: 1);
  }

  Future<void> clearSearch() async {
    if (_searchKeyword == null) return;
    _searchKeyword = null;
    _selectedSlugs.clear();
    _isSelectionMode = false;
    await loadVideos(page: 1);
  }

  Future<void> nextPage() async {
    if (_currentPage < _totalPages && !_isLoading) {
      await loadVideos(page: _currentPage + 1);
    }
  }

  Future<void> previousPage() async {
    if (_currentPage > 1 && !_isLoading) {
      await loadVideos(page: _currentPage - 1);
    }
  }

  Future<void> goToPage(int page) async {
    if (page >= 1 && page <= _totalPages && page != _currentPage && !_isLoading) {
      await loadVideos(page: page);
    }
  }

  Future<void> refresh() async {
    await loadVideos(page: _currentPage);
  }
}
