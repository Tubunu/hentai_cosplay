import 'dart:convert';
import 'album_item.dart';

enum TaskStatus {
  idle,
  queued,
  downloading,
  paused,
  completed,
  failed,
}

enum ImageTaskStatus {
  pending,
  downloading,
  success,
  skipped,
  failed,
}

class ImageDownloadTask {
  final int index;
  final String originalUrl;
  final String savePath;
  ImageTaskStatus status;
  int downloadedBytes;
  int totalBytes;
  String? error;

  ImageDownloadTask({
    required this.index,
    required this.originalUrl,
    required this.savePath,
    this.status = ImageTaskStatus.pending,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  double get progress => totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'index': index,
    'originalUrl': originalUrl,
    'savePath': savePath,
    'status': status.name,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'error': error,
  };

  factory ImageDownloadTask.fromJson(Map<String, dynamic> json) {
    return ImageDownloadTask(
      index: ((json['index'] ?? 1) as num).toInt(),
      originalUrl: json['originalUrl'] as String? ?? '',
      savePath: json['savePath'] as String? ?? '',
      status: ImageTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ImageTaskStatus.pending,
      ),
      downloadedBytes: ((json['downloadedBytes'] ?? 0) as num).toInt(),
      totalBytes: ((json['totalBytes'] ?? 0) as num).toInt(),
      error: json['error'] as String?,
    );
  }
}

class AlbumDownloadTask {
  final String id;
  final AlbumItem albumItem;
  String targetFolder;
  TaskStatus status;
  int totalImages;
  int downloadedImages;
  int skippedImages;
  int failedImages;
  int downloadedBytes;
  int totalBytes;
  DateTime? startTime;
  DateTime? finishTime;
  List<ImageDownloadTask> imageTasks;
  double speed; // bytes per second
  String? errorMessage;
  final bool isVideo;
  final String? videoUrl;
  final String? duration;

  AlbumDownloadTask({
    String? id,
    required this.albumItem,
    this.targetFolder = '',
    this.status = TaskStatus.queued,
    this.totalImages = 0,
    this.downloadedImages = 0,
    this.skippedImages = 0,
    this.failedImages = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.startTime,
    this.finishTime,
    List<ImageDownloadTask>? imageTasks,
    this.speed = 0.0,
    this.errorMessage,
    this.isVideo = false,
    this.videoUrl,
    this.duration,
  })  : id = id ?? (albumItem.slug.isNotEmpty ? albumItem.slug : '${DateTime.now().millisecondsSinceEpoch}_${albumItem.title.hashCode.abs()}'),
        imageTasks = imageTasks ?? [];

  int get finishedImages => downloadedImages + skippedImages + failedImages;

  double get progress {
    if (totalImages <= 0) return 0.0;
    final val = (downloadedImages + skippedImages) / totalImages;
    return val.isNaN ? 0.0 : val.clamp(0.0, 1.0);
  }

  bool get isDone =>
      status == TaskStatus.completed ||
      status == TaskStatus.failed ||
      (totalImages > 0 && (downloadedImages + skippedImages + failedImages) >= totalImages);

  bool get isRunning => status == TaskStatus.downloading;

  Map<String, dynamic> toJson() => {
    'id': id,
    'albumItem': albumItem.toJson(),
    'targetFolder': targetFolder,
    'status': status.name,
    'totalImages': totalImages,
    'downloadedImages': downloadedImages,
    'skippedImages': skippedImages,
    'failedImages': failedImages,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'startTime': startTime?.toIso8601String(),
    'finishTime': finishTime?.toIso8601String(),
    'imageTasks': imageTasks.map((e) => e.toJson()).toList(),
    'errorMessage': errorMessage,
    'isVideo': isVideo,
    'videoUrl': videoUrl,
    'duration': duration,
  };

  factory AlbumDownloadTask.fromJson(Map<String, dynamic> json) {
    final rawAlbum = (json['albumItem'] as Map<String, dynamic>?) ?? {};
    final item = AlbumItem.fromJson(rawAlbum);
    final rawImages = json['imageTasks'] as List<dynamic>?;
    final imageTasks = rawImages != null
        ? rawImages.map((e) => ImageDownloadTask.fromJson(e as Map<String, dynamic>)).toList()
        : <ImageDownloadTask>[];

    return AlbumDownloadTask(
      id: json['id'] as String? ?? (item.slug.isNotEmpty ? item.slug : DateTime.now().millisecondsSinceEpoch.toString()),
      albumItem: item,
      targetFolder: json['targetFolder'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.queued,
      ),
      totalImages: ((json['totalImages'] ?? item.imageUrls.length) as num).toInt(),
      downloadedImages: ((json['downloadedImages'] ?? 0) as num).toInt(),
      skippedImages: ((json['skippedImages'] ?? 0) as num).toInt(),
      failedImages: ((json['failedImages'] ?? 0) as num).toInt(),
      downloadedBytes: ((json['downloadedBytes'] ?? 0) as num).toInt(),
      totalBytes: ((json['totalBytes'] ?? 0) as num).toInt(),
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime']) : null,
      finishTime: json['finishTime'] != null ? DateTime.tryParse(json['finishTime']) : null,
      imageTasks: imageTasks,
      errorMessage: json['errorMessage'] as String?,
      isVideo: json['isVideo'] as bool? ?? false,
      videoUrl: json['videoUrl'] as String?,
      duration: json['duration'] as String?,
    );
  }

  static List<AlbumDownloadTask> listFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => AlbumDownloadTask.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<AlbumDownloadTask> tasks) {
    return jsonEncode(tasks.map((e) => e.toJson()).toList());
  }
}
