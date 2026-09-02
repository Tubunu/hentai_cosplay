import 'package:flutter/foundation.dart';
import '../models/video_item.dart';
import '../services/xvideos/xvideos_api_service.dart';

class XVideosAuthorProvider extends ChangeNotifier {
  final String authorName;
  final String? authorUrl;

  List<VideoItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _isLoading = false;
  String? _errorMessage;

  XVideosSubSort _subSort = XVideosSubSort.none;

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  XVideosAuthorProvider({
    required this.authorName,
    this.authorUrl,
  });

  List<VideoItem> get items => _items;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  XVideosSubSort get subSort => _subSort;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedSlugs => _selectedSlugs;
  int get selectedCount => _selectedSlugs.length;
  List<VideoItem> get selectedItems =>
      _items.where((it) => _selectedSlugs.contains(it.slug)).toList();

  bool isSelected(VideoItem item) => _selectedSlugs.contains(item.slug);

  void toggleSelection(VideoItem item) {
    if (_selectedSlugs.contains(item.slug)) {
      _selectedSlugs.remove(item.slug);
    } else {
      _selectedSlugs.add(item.slug);
    }
    notifyListeners();
  }

  void selectAll() {
    for (final it in _items) {
      _selectedSlugs.add(it.slug);
    }
    notifyListeners();
  }

  void deselectAll() {
    _selectedSlugs.clear();
    notifyListeners();
  }

  void setSelectionMode(bool mode) {
    _isSelectionMode = mode;
    if (!mode) {
      _selectedSlugs.clear();
    }
    notifyListeners();
  }

  Future<void> loadPage(int page, {bool clearItems = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    if (clearItems) {
      _items = [];
    }
    notifyListeners();

    try {
      final response = await XVideosApiService.fetchAuthorVideos(
        authorName: authorName,
        authorUrl: authorUrl,
        page: page,
        subSort: _subSort,
      );

      if (response != null && response.items.isNotEmpty) {
        _items = response.items;
        _currentPage = response.page;
        _totalPages = response.totalPages;
        _total = response.total;
        _errorMessage = null;
      } else {
        if (_items.isEmpty) {
          _errorMessage = '未找到创作者「$authorName」的相关作品';
        }
      }
    } catch (e) {
      _errorMessage = '加载失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchSubSort(XVideosSubSort newSort) async {
    if (_subSort == newSort && _items.isNotEmpty) return;
    _subSort = newSort;
    _currentPage = 1;
    await loadPage(1, clearItems: true);
  }

  Future<void> refresh() async {
    await loadPage(_currentPage, clearItems: false);
  }

  Future<void> nextPage() async {
    if (_currentPage < _totalPages) {
      await loadPage(_currentPage + 1, clearItems: true);
    }
  }

  Future<void> prevPage() async {
    if (_currentPage > 1) {
      await loadPage(_currentPage - 1, clearItems: true);
    }
  }
}
