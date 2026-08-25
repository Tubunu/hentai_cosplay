import 'dart:convert';

enum JableDownloadStatus {
  waiting,
  downloading,
  merging,
  completed,
  failed,
  cancelled,
  paused,
}

class JableDownloadTask {
  final String id;
  final String url;
  String name;
  String thumbnailUrl;
  JableDownloadStatus status;
  double progress; // 0.0 ~ 100.0
  int totalSegments;
  int completedSegments;
  String speed;
  String? errorMsg;
  String destPath;
  String siteName;
  String duration;
  DateTime? createdAt;
  DateTime? finishedAt;

  JableDownloadTask({
    required this.id,
    required this.url,
    required this.name,
    this.thumbnailUrl = '',
    this.status = JableDownloadStatus.waiting,
    this.progress = 0.0,
    this.totalSegments = 0,
    this.completedSegments = 0,
    this.speed = '0 KB/s',
    this.errorMsg,
    required this.destPath,
    this.siteName = 'JableTV',
    this.duration = '',
    DateTime? createdAt,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'thumbnailUrl': thumbnailUrl,
      'status': status.name,
      'progress': progress,
      'totalSegments': totalSegments,
      'completedSegments': completedSegments,
      'speed': speed,
      'errorMsg': errorMsg,
      'destPath': destPath,
      'siteName': siteName,
      'duration': duration,
      'createdAt': createdAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
    };
  }

  factory JableDownloadTask.fromMap(Map<String, dynamic> map) {
    return JableDownloadTask(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      name: map['name'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      status: JableDownloadStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JableDownloadStatus.waiting,
      ),
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      totalSegments: (map['totalSegments'] as num?)?.toInt() ?? 0,
      completedSegments: (map['completedSegments'] as num?)?.toInt() ?? 0,
      speed: map['speed'] ?? '0 KB/s',
      errorMsg: map['errorMsg'],
      destPath: map['destPath'] ?? '',
      siteName: map['siteName'] ?? 'JableTV',
      duration: map['duration'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      finishedAt: map['finishedAt'] != null ? DateTime.tryParse(map['finishedAt']) : null,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory JableDownloadTask.fromJson(String source) => JableDownloadTask.fromMap(jsonDecode(source));
}

class JableHistoryRecord {
  final String id;
  final String url;
  final String name;
  final String size;
  final String date;
  final String destPath;
  final String thumbnailUrl;
  final String siteName;
  final String duration;
  final DateTime completedAt;

  JableHistoryRecord({
    required this.id,
    required this.url,
    required this.name,
    required this.size,
    required this.date,
    required this.destPath,
    this.thumbnailUrl = '',
    this.siteName = 'JableTV',
    this.duration = '',
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'size': size,
      'date': date,
      'destPath': destPath,
      'thumbnailUrl': thumbnailUrl,
      'siteName': siteName,
      'duration': duration,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory JableHistoryRecord.fromMap(Map<String, dynamic> map) {
    return JableHistoryRecord(
      id: map['id'] ?? '',
      url: map['url'] ?? '',
      name: map['name'] ?? '',
      size: map['size'] ?? '',
      date: map['date'] ?? '',
      destPath: map['destPath'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      siteName: map['siteName'] ?? 'JableTV',
      duration: map['duration'] ?? '',
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt']) : null,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory JableHistoryRecord.fromJson(String source) => JableHistoryRecord.fromMap(jsonDecode(source));
}
