import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/album_item.dart';
import '../models/app_config.dart';

class LocalAlbumFolder {
  final String folderPath;
  final String title;
  final String author;
  final String? coverPath;
  final int imageCount;
  final int totalBytes;
  final DateTime modifiedAt;
  final List<String> imagePaths;
  final MediaSourceType sourceType;
  final Map<String, dynamic>? metadata;

  LocalAlbumFolder({
    required this.folderPath,
    required this.title,
    required this.author,
    this.coverPath,
    required this.imageCount,
    required this.totalBytes,
    required this.modifiedAt,
    required this.imagePaths,
    this.sourceType = MediaSourceType.hc,
    this.metadata,
  });
}

class StorageService {
  /// Request storage permissions
  static Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      final statuses = await [
        Permission.photos,
        Permission.videos,
        Permission.storage,
      ].request();

      final photosGranted = statuses[Permission.photos]?.isGranted ?? await Permission.photos.isGranted;
      final videosGranted = statuses[Permission.videos]?.isGranted ?? await Permission.videos.isGranted;
      final storageGranted = statuses[Permission.storage]?.isGranted ?? await Permission.storage.isGranted;
      final manageGranted = await Permission.manageExternalStorage.isGranted;

      return photosGranted || videosGranted || storageGranted || manageGranted;
    }
    return true;
  }

  /// Get the default download directory
  static Future<String> getDefaultDownloadPath() async {
    try {
      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Pictures/HentaiCosplay');
        if (!await dir.exists()) {
          try {
            await dir.create(recursive: true);
            return dir.path;
          } catch (_) {}
        } else {
          return dir.path;
        }

        final downloadsDir = Directory('/storage/emulated/0/Download/HentaiCosplay');
        if (!await downloadsDir.exists()) {
          try {
            await downloadsDir.create(recursive: true);
            return downloadsDir.path;
          } catch (_) {}
        } else {
          return downloadsDir.path;
        }

        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final pth = p.join(extDir.path, 'HentaiCosplay');
          await Directory(pth).create(recursive: true);
          return pth;
        }
      }

      final docDir = await getApplicationDocumentsDirectory();
      final target = p.join(docDir.path, 'HentaiCosplay');
      final targetDir = Directory(target);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return target;
    } catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      return docDir.path;
    }
  }

  /// Resolve and reconcile valid path dynamically (especially for iOS sandbox container UUID migration)
  static Future<String> resolveValidPath(String savedPath) async {
    try {
      if (Platform.isIOS) {
        final currentDocDir = await getApplicationDocumentsDirectory();
        if (savedPath.isEmpty || !savedPath.contains('/Documents')) {
          return await getDefaultDownloadPath();
        }
        final docIndex = savedPath.indexOf('/Documents');
        final subPath = savedPath.substring(docIndex + '/Documents'.length);
        final cleanSub = subPath.startsWith('/') ? subPath.substring(1) : subPath;
        final resolved = cleanSub.isNotEmpty ? p.join(currentDocDir.path, cleanSub) : p.join(currentDocDir.path, 'HentaiCosplay');
        final dir = Directory(resolved);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return resolved;
      }
    } catch (_) {}

    if (savedPath.isNotEmpty) return savedPath;
    return await getDefaultDownloadPath();
  }

  /// Select a custom save directory
  static Future<String?> pickSaveDirectory() async {
    await requestStoragePermissions();
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null && result.isNotEmpty) {
      final dir = Directory(result);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return result;
    }
    return null;
  }

  /// Scan a local folder to check for downloaded images and albums (runs in background isolate)
  static Future<List<LocalAlbumFolder>> scanLocalAlbums(String baseDirPath) async {
    try {
      return await Isolate.run(() => _scanLocalAlbumsSync(baseDirPath));
    } catch (_) {
      return _scanLocalAlbumsSync(baseDirPath);
    }
  }

  static List<LocalAlbumFolder> _scanLocalAlbumsSync(String baseDirPath) {
    final List<LocalAlbumFolder> albums = [];
    final baseDir = Directory(baseDirPath);
    if (!baseDir.existsSync()) return albums;

    const validExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

    void inspectFolder(Directory dir, {String? defaultAuthor}) {
      try {
        final entities = dir.listSync();
        final List<String> imgFiles = [];
        int bytes = 0;
        Map<String, dynamic>? meta;

        for (final e in entities) {
          if (e is File) {
            final filename = p.basename(e.path);
            if (filename == kAlbumMetadataFilename || filename == kMztMetadataFilename) {
              try {
                final content = e.readAsStringSync();
                meta = jsonDecode(content) as Map<String, dynamic>?;
              } catch (_) {}
            } else {
              final ext = p.extension(e.path).replaceAll('.', '').toLowerCase();
              if (validExts.contains(ext)) {
                imgFiles.add(e.path);
                try {
                  bytes += e.lengthSync();
                } catch (_) {}
              }
            }
          }
        }

        // Natural sort image paths (e.g. 1.jpg, 2.jpg, 10.jpg)
        imgFiles.sort((a, b) {
          final nameA = p.basenameWithoutExtension(a);
          final nameB = p.basenameWithoutExtension(b);
          final intA = int.tryParse(nameA);
          final intB = int.tryParse(nameB);
          if (intA != null && intB != null) return intA.compareTo(intB);
          return nameA.compareTo(nameB);
        });

        if (imgFiles.isNotEmpty) {
          final folderName = p.basename(dir.path);
          final stat = dir.statSync();
          final title = meta?['title'] ?? meta?['item']?['title'] ?? folderName;
          final itemData = (meta?['item'] as Map<String, dynamic>?) ?? {};
          final author = meta?['author'] ?? defaultAuthor ?? AlbumItem.inferAuthor(title, itemData);

          // Infer exact source from metadata, rawData, urls, and directory
          final detectedSource = AlbumItem.inferSource(
            sourceTypeName: meta?['sourceType']?.toString(),
            detailUrl: meta?['detailUrl']?.toString() ?? meta?['item']?['detailUrl']?.toString(),
            coverUrl: meta?['coverUrl']?.toString(),
            imageUrls: (meta?['imageUrls'] as List?) ?? (meta?['item']?['imageUrls'] as List?),
            rawData: meta?['rawData'] as Map<String, dynamic>? ?? meta?['item'] as Map<String, dynamic>?,
            folderName: folderName,
          );

          albums.add(
            LocalAlbumFolder(
              folderPath: dir.path,
              title: title,
              author: author,
              coverPath: imgFiles.first,
              imageCount: imgFiles.length,
              totalBytes: bytes,
              modifiedAt: stat.modified,
              imagePaths: imgFiles,
              sourceType: detectedSource,
              metadata: meta,
            ),
          );
        }
      } catch (_) {}
    }

    try {
      final topEntities = baseDir.listSync();
      for (final e in topEntities) {
        if (e is Directory) {
          final name = p.basename(e.path);
          if (name == 'archive') {
            // Traverse archive/<author>/<album>
            try {
              final authorDirs = e.listSync();
              for (final ad in authorDirs) {
                if (ad is Directory) {
                  final authorName = p.basename(ad.path);
                  final albumDirs = ad.listSync();
                  for (final alb in albumDirs) {
                    if (alb is Directory) {
                      inspectFolder(alb, defaultAuthor: authorName);
                    }
                  }
                }
              }
            } catch (_) {}
          } else {
            inspectFolder(e);
          }
        }
      }
    } catch (_) {}

    // Sort by modified time descending
    albums.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return albums;
  }

  /// Calculate the total size in bytes of a folder
  static Future<int> getFolderSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    int bytes = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          bytes += await entity.length();
        }
      }
    } catch (_) {}
    return bytes;
  }

  /// Delete an album folder
  static Future<bool> deleteAlbumFolder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
