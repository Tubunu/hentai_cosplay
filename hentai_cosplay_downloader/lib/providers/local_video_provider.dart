import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/video_item.dart';

enum VideoSortOption {
  dateDesc('时间: 从新到旧'),
  dateAsc('时间: 从旧到新'),
  nameAsc('名称: A - Z'),
  nameDesc('名称: Z - A'),
  sizeDesc('大小: 从高到低'),
  sizeAsc('大小: 从低到高');

  final String label;
  const VideoSortOption(this.label);
}

class LocalVideoProvider extends ChangeNotifier {
  List<LocalVideoItem> _videos = [];
  bool _isScanning = false;
  String _searchQuery = '';
  VideoSortOption _sortOption = VideoSortOption.dateDesc;
  int _totalBytes = 0;
  List<LocalVideoItem>? _cachedVideos;
  final Set<String> _videoTitles = {};
  final Set<String> _videoSourceUrls = {};
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

  List<LocalVideoItem> get videos {
    _cachedVideos ??= _getFilteredAndSortedVideos();
    return _cachedVideos!;
  }
  bool get isScanning => _isScanning;
  String get searchQuery => _searchQuery;
  VideoSortOption get sortOption => _sortOption;
  int get totalCount => _videos.length;
  int get totalBytes => _totalBytes;

  bool isVideoDownloaded({required String title, String detailUrl = ''}) {
    if (_videoTitles.contains(title)) return true;
    if (detailUrl.isNotEmpty && _videoSourceUrls.contains(detailUrl)) return true;
    return false;
  }

  void _rebuildIndex() {
    _videoTitles.clear();
    _videoSourceUrls.clear();
    for (final v in _videos) {
      if (v.title.isNotEmpty) _videoTitles.add(v.title);
      if (v.sourceUrl.isNotEmpty) _videoSourceUrls.add(v.sourceUrl);
    }
  }

  String get formattedTotalSize {
    if (_totalBytes <= 0) return '0 MB';
    if (_totalBytes < 1024 * 1024) {
      return '${(_totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (_totalBytes < 1024 * 1024 * 1024) {
      return '${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(_totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void setSortOption(VideoSortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    _cachedVideos = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (_searchQuery == clean) return;
    _searchQuery = clean;
    _cachedVideos = null;
    notifyListeners();
  }

  Future<void> scanLocalVideos(String baseSavePath) async {
    if (baseSavePath.trim().isEmpty) return;
    _isScanning = true;
    notifyListeners();

    final videoDir = Directory(p.join(baseSavePath, 'video'));
    if (!await videoDir.exists()) {
      _videos = [];
      _totalBytes = 0;
      _cachedVideos = null;
      _rebuildIndex();
      _isScanning = false;
      notifyListeners();
      return;
    }

    try {
      final res = await Isolate.run(() => _scanVideosSync(videoDir.path));
      _videos = res.$1;
      _totalBytes = res.$2;
      _cachedVideos = null;
      _rebuildIndex();
    } catch (e) {
      debugPrint('Error scanning local videos: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  static (List<LocalVideoItem>, int) _scanVideosSync(String videoDirPath) {
    final List<LocalVideoItem> found = [];
    int totalSize = 0;
    final videoDir = Directory(videoDirPath);
    if (!videoDir.existsSync()) return (found, 0);

    final entities = videoDir.listSync(recursive: true, followLinks: false);
    const videoExtensions = ['.mp4', '.mkv', '.webm', '.mov', '.avi', '.flv', '.ts'];

    for (final entity in entities) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (videoExtensions.contains(ext)) {
          final stat = entity.statSync();
          totalSize += stat.size;

          final baseNameNoExt = p.basenameWithoutExtension(entity.path);
          final parentDir = entity.parent.path;

          // Check if companion metadata exists
          final metaFile = File(p.join(parentDir, '$baseNameNoExt.json'));
          Map<String, dynamic>? meta;
          if (metaFile.existsSync()) {
            try {
              final metaContent = metaFile.readAsStringSync();
              meta = jsonDecode(metaContent) as Map<String, dynamic>?;
            } catch (_) {}
          }

          // Check companion cover
          String? coverPath;
          final coverJpg = File(p.join(parentDir, '$baseNameNoExt.jpg'));
          final coverPng = File(p.join(parentDir, '$baseNameNoExt.png'));
          if (coverJpg.existsSync()) {
            coverPath = coverJpg.path;
          } else if (coverPng.existsSync()) {
            coverPath = coverPng.path;
          }

          final title = meta?['title'] as String? ?? baseNameNoExt;
          final author = meta?['author'] as String? ?? p.basename(parentDir);
          final duration = meta?['duration'] as String? ?? '';
          final sourceUrl = meta?['sourceUrl'] as String? ?? '';
          final tags = (meta?['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          found.add(
            LocalVideoItem(
              id: entity.path,
              title: title,
              author: author.isEmpty || author == 'video' ? '未知作者' : author,
              filePath: entity.path,
              coverPath: coverPath,
              fileSizeBytes: stat.size,
              createdAt: stat.modified,
              duration: duration,
              sourceUrl: sourceUrl,
              tags: tags,
            ),
          );
        }
      }
    }
    return (found, totalSize);
  }

  Future<bool> deleteVideo(LocalVideoItem item) async {
    try {
      final videoFile = File(item.filePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      // Also clean companion metadata and cover
      final baseNoExt = p.basenameWithoutExtension(item.filePath);
      final parentDir = p.dirname(item.filePath);
      final metaFile = File(p.join(parentDir, '$baseNoExt.json'));
      if (await metaFile.exists()) await metaFile.delete();

      final coverJpg = File(p.join(parentDir, '$baseNoExt.jpg'));
      if (await coverJpg.exists()) await coverJpg.delete();

      final coverPng = File(p.join(parentDir, '$baseNoExt.png'));
      if (await coverPng.exists()) await coverPng.delete();

      _videos.removeWhere((v) => v.id == item.id);
      _totalBytes -= item.fileSizeBytes;
      _cachedVideos = null;
      _rebuildIndex();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting video: $e');
      return false;
    }
  }

  List<LocalVideoItem> _getFilteredAndSortedVideos() {
    List<LocalVideoItem> list = List.of(_videos);

    if (_searchQuery.isNotEmpty) {
      list = list.where((v) {
        return v.title.toLowerCase().contains(_searchQuery) ||
            v.author.toLowerCase().contains(_searchQuery) ||
            v.tags.any((t) => t.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    switch (_sortOption) {
      case VideoSortOption.dateDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case VideoSortOption.dateAsc:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case VideoSortOption.nameAsc:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case VideoSortOption.nameDesc:
        list.sort((a, b) => b.title.compareTo(a.title));
        break;
      case VideoSortOption.sizeDesc:
        list.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case VideoSortOption.sizeAsc:
        list.sort((a, b) => a.fileSizeBytes.compareTo(b.fileSizeBytes));
        break;
    }

    return list;
  }
}
