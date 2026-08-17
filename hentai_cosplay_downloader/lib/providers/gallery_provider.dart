import 'package:flutter/material.dart';
import '../services/storage_service.dart';

enum GallerySortMode {
  dateDesc('时间最新 (默认)'),
  dateAsc('时间最早'),
  sizeDesc('占用空间 (从高到低)'),
  sizeAsc('占用空间 (从低到高)'),
  titleAsc('名称 (A-Z)'),
  imagesDesc('图片数 (从多到少)'),
  imagesAsc('图片数 (从少到多)');

  final String label;
  const GallerySortMode(this.label);
}

class GalleryProvider extends ChangeNotifier {
  List<LocalAlbumFolder> _localAlbums = [];
  bool _isScanning = false;
  String _searchQuery = '';
  GallerySortMode _sortMode = GallerySortMode.dateDesc;

  GallerySortMode get sortMode => _sortMode;

  List<LocalAlbumFolder> get localAlbums {
    List<LocalAlbumFolder> list = _localAlbums;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((alb) {
        return alb.title.toLowerCase().contains(q) || alb.author.toLowerCase().contains(q);
      }).toList();
    }

    final sorted = List<LocalAlbumFolder>.from(list);
    switch (_sortMode) {
      case GallerySortMode.dateDesc:
        sorted.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case GallerySortMode.dateAsc:
        sorted.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
        break;
      case GallerySortMode.sizeDesc:
        sorted.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
        break;
      case GallerySortMode.sizeAsc:
        sorted.sort((a, b) => a.totalBytes.compareTo(b.totalBytes));
        break;
      case GallerySortMode.titleAsc:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case GallerySortMode.imagesDesc:
        sorted.sort((a, b) => b.imageCount.compareTo(a.imageCount));
        break;
      case GallerySortMode.imagesAsc:
        sorted.sort((a, b) => a.imageCount.compareTo(b.imageCount));
        break;
    }
    return sorted;
  }

  bool get isScanning => _isScanning;
  int get albumCount => _localAlbums.length;
  int get totalImages => _localAlbums.fold(0, (sum, a) => sum + a.imageCount);

  void setSortMode(GallerySortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> scanLocalDirectory(String savePath) async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      String targetPath = savePath;
      if (targetPath.isEmpty) {
        targetPath = await StorageService.getDefaultDownloadPath();
      } else {
        targetPath = await StorageService.resolveValidPath(targetPath);
      }
      _localAlbums = await StorageService.scanLocalAlbums(targetPath);
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<bool> deleteLocalAlbum(LocalAlbumFolder album) async {
    final success = await StorageService.deleteAlbumFolder(album.folderPath);
    if (success) {
      _localAlbums.removeWhere((a) => a.folderPath == album.folderPath);
      notifyListeners();
    }
    return success;
  }
}
