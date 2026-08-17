import 'dart:convert';
import 'pack_item.dart';

enum TaskStatus {
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

/// Represents the download state of an individual image inside a pack
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
      index: json['index'] as int? ?? 1,
      originalUrl: json['originalUrl'] as String? ?? '',
      savePath: json['savePath'] as String? ?? '',
      status: ImageTaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ImageTaskStatus.pending,
      ),
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

/// Represents the entire pack download task
class PackDownloadTask {
  final String id;
  final PackItem packItem;
  String targetFolder;
  TaskStatus status;

  int totalImages;
  int downloadedImages;
  int skippedImages;
  int failedImages;

  List<ImageDownloadTask> imageTasks;
  DateTime? startTime;
  DateTime? finishTime;
  double speedBytesPerSec;
  String? errorMessage;

  PackDownloadTask({
    required this.id,
    required this.packItem,
    required this.targetFolder,
    this.status = TaskStatus.queued,
    this.totalImages = 0,
    this.downloadedImages = 0,
    this.skippedImages = 0,
    this.failedImages = 0,
    List<ImageDownloadTask>? imageTasks,
    this.startTime,
    this.finishTime,
    this.speedBytesPerSec = 0,
    this.errorMessage,
  }) : imageTasks = imageTasks ?? [];

  int get finishedImages => downloadedImages + skippedImages + failedImages;

  double get progress {
    if (totalImages == 0) return 0.0;
    return (finishedImages / totalImages).clamp(0.0, 1.0);
  }

  bool get isDone => status == TaskStatus.completed || status == TaskStatus.failed;
  bool get isRunning => status == TaskStatus.downloading;

  Map<String, dynamic> toJson() => {
    'id': id,
    'packItem': packItem.rawData,
    'targetFolder': targetFolder,
    'status': status.name,
    'totalImages': totalImages,
    'downloadedImages': downloadedImages,
    'skippedImages': skippedImages,
    'failedImages': failedImages,
    'startTime': startTime?.toIso8601String(),
    'finishTime': finishTime?.toIso8601String(),
    'errorMessage': errorMessage,
  };

  factory PackDownloadTask.fromJson(Map<String, dynamic> json) {
    final rawPack = (json['packItem'] as Map<String, dynamic>?) ?? {};
    final item = PackItem.fromJson(rawPack);

    return PackDownloadTask(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      packItem: item,
      targetFolder: json['targetFolder'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.queued,
      ),
      totalImages: json['totalImages'] as int? ?? item.urls.length,
      downloadedImages: json['downloadedImages'] as int? ?? 0,
      skippedImages: json['skippedImages'] as int? ?? 0,
      failedImages: json['failedImages'] as int? ?? 0,
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime']) : null,
      finishTime: json['finishTime'] != null ? DateTime.tryParse(json['finishTime']) : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  static List<PackDownloadTask> listFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => PackDownloadTask.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<PackDownloadTask> tasks) {
    return jsonEncode(tasks.map((e) => e.toJson()).toList());
  }
}
