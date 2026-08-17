import 'dart:convert';

/// Represents a completed download batch or session in history
class HistoryRecord {
  final String id;
  final String timestamp;
  final String savePath;
  final int packsDownloaded;
  final int packsSkipped;
  final int imagesDownloaded;
  final int imagesSkipped;
  final int imagesFailed;
  final double durationSec;
  final List<String> packTitles;

  HistoryRecord({
    required this.id,
    required this.timestamp,
    required this.savePath,
    required this.packsDownloaded,
    required this.packsSkipped,
    required this.imagesDownloaded,
    required this.imagesSkipped,
    required this.imagesFailed,
    required this.durationSec,
    required this.packTitles,
  });

  int get totalPacks => packsDownloaded + packsSkipped;
  int get totalImages => imagesDownloaded + imagesSkipped + imagesFailed;

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] ?? '',
      savePath: json['save_path'] ?? json['savePath'] ?? '',
      packsDownloaded: (json['packs_downloaded'] ?? json['packsDownloaded'] ?? 0) as int,
      packsSkipped: (json['packs_skipped'] ?? json['packsSkipped'] ?? 0) as int,
      imagesDownloaded: (json['images_downloaded'] ?? json['imagesDownloaded'] ?? 0) as int,
      imagesSkipped: (json['images_skipped'] ?? json['imagesSkipped'] ?? 0) as int,
      imagesFailed: (json['images_failed'] ?? json['imagesFailed'] ?? 0) as int,
      durationSec: ((json['duration_sec'] ?? json['durationSec'] ?? 0.0) as num).toDouble(),
      packTitles: (json['pack_titles'] ?? json['packTitles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp,
    'save_path': savePath,
    'packs_downloaded': packsDownloaded,
    'packs_skipped': packsSkipped,
    'images_downloaded': imagesDownloaded,
    'images_skipped': imagesSkipped,
    'images_failed': imagesFailed,
    'duration_sec': durationSec,
    'pack_titles': packTitles,
  };

  static List<HistoryRecord> listFromJson(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<HistoryRecord> records) {
    return jsonEncode(records.map((e) => e.toJson()).toList());
  }
}
