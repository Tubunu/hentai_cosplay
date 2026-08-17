import 'package:flutter/material.dart';
import '../services/storage_service.dart';

enum GallerySortMode {
  timeDesc,
  timeAsc,
  author,
}

class GalleryProvider extends ChangeNotifier {
  List<LocalPackInfo> _allPacks = [];
  bool _isLoading = false;
  String _searchQuery = '';
  GallerySortMode _sortMode = GallerySortMode.timeDesc;
  bool _isArchiving = false;
  String _archiveStatusText = '';

  List<LocalPackInfo> get packs {
    List<LocalPackInfo> list = List.from(_allPacks);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      list = list.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.author.toLowerCase().contains(query) ||
            p.name.toLowerCase().contains(query);
      }).toList();
    }

    switch (_sortMode) {
      case GallerySortMode.timeDesc:
        list.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
        break;
      case GallerySortMode.timeAsc:
        list.sort((a, b) => a.modifiedTime.compareTo(b.modifiedTime));
        break;
      case GallerySortMode.author:
        list.sort((a, b) => a.author.compareTo(b.author));
        break;
    }

    return list;
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  GallerySortMode get sortMode => _sortMode;
  bool get isArchiving => _isArchiving;
  String get archiveStatusText => _archiveStatusText;
  int get totalPacks => _allPacks.length;
  int get totalImages => _allPacks.fold(0, (sum, p) => sum + p.imageCount);

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setSortMode(GallerySortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  Future<void> scanLocalDirectory(String basePath) async {
    if (basePath.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      _allPacks = await StorageService.scanLocalPacks(basePath);
    } catch (e) {
      debugPrint('Scan local directory error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> organizeAndArchive(String basePath, {String strategy = 'author'}) async {
    if (basePath.isEmpty || _isArchiving) return 0;
    _isArchiving = true;
    _archiveStatusText = '正在整理归档中...';
    notifyListeners();

    int count = 0;
    try {
      count = await StorageService.organizeAndArchivePacks(
        basePath,
        strategy: strategy,
        onProgress: (msg) {
          _archiveStatusText = msg;
          notifyListeners();
        },
      );
      await scanLocalDirectory(basePath);
    } finally {
      _isArchiving = false;
      _archiveStatusText = '';
      notifyListeners();
    }
    return count;
  }
}
