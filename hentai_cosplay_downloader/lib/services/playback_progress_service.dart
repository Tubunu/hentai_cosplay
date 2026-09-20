import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 视频播放进度管理服务，支持跨会话记忆与断点续播
class PlaybackProgressService {
  static const String _kStorageKey = 'video_playback_progress_map_v1';
  static const int _kMaxRecords = 300;

  static Map<String, dynamic>? _memoryCache;

  static Future<Map<String, dynamic>> _loadMap() async {
    if (_memoryCache != null) return _memoryCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _memoryCache = Map<String, dynamic>.from(decoded);
          return _memoryCache!;
        }
      }
    } catch (e) {
      debugPrint('[PlaybackProgress] Load error: $e');
    }
    _memoryCache = {};
    return _memoryCache!;
  }

  static Future<void> _saveMap(Map<String, dynamic> map) async {
    _memoryCache = map;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStorageKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[PlaybackProgress] Save error: $e');
    }
  }

  /// 计算稳定、跨进程重启一致的确定性哈希值 (32-bit FNV-1a)
  static String _stableHash(String input) {
    var hash = 0x811c9dc5;
    final bytes = utf8.encode(input);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// 生成一致的视频索引 Key（跨应用重启保持确定性）
  /// 优先级：本地路径 > 永久网页URL(webPlayerUrl) > 视频标题(title) > 清洗后的串流直链(remoteUrl)
  static String computeKey({
    String? filePath,
    String? webPlayerUrl,
    String? title,
    String? remoteUrl,
  }) {
    if (filePath != null && filePath.trim().isNotEmpty) {
      return 'file_${_stableHash(filePath.trim())}';
    }
    if (webPlayerUrl != null && webPlayerUrl.trim().isNotEmpty) {
      return 'web_${_stableHash(webPlayerUrl.trim())}';
    }
    if (title != null && title.trim().isNotEmpty) {
      return 'title_${_stableHash(title.trim())}';
    }
    if (remoteUrl != null && remoteUrl.trim().isNotEmpty) {
      // 清洗剔除临时查询参数（如鉴权 token、expires 时间戳）
      String cleanedUrl = remoteUrl.trim();
      final qIndex = cleanedUrl.indexOf('?');
      if (qIndex != -1) {
        cleanedUrl = cleanedUrl.substring(0, qIndex);
      }
      return 'url_${_stableHash(cleanedUrl)}';
    }
    return 'unknown_video';
  }

  /// 记录当前视频播放秒数
  static Future<void> saveProgress({
    required String key,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    if (key.isEmpty || positionSeconds <= 0) return;

    try {
      final map = await _loadMap();

      // 播放到最后 15 秒内，视为已看完，自动清除记忆点
      if (durationSeconds > 0 && positionSeconds >= durationSeconds - 15) {
        if (map.containsKey(key)) {
          map.remove(key);
          await _saveMap(map);
        }
        return;
      }

      // 少于 10 秒不单独记录，避免误触
      if (positionSeconds < 10) return;

      map[key] = {
        'pos': positionSeconds,
        'dur': durationSeconds,
        'time': DateTime.now().millisecondsSinceEpoch,
      };

      // 超量清理最旧记录
      if (map.length > _kMaxRecords) {
        final sortedEntries = map.entries.toList()
          ..sort((a, b) {
            final valA = a.value;
            final valB = b.value;
            final timeA = (valA is Map ? (valA['time'] as num?)?.toInt() : null) ?? 0;
            final timeB = (valB is Map ? (valB['time'] as num?)?.toInt() : null) ?? 0;
            return timeA.compareTo(timeB);
          });
        final removeCount = map.length - _kMaxRecords;
        for (int i = 0; i < removeCount; i++) {
          map.remove(sortedEntries[i].key);
        }
      }

      await _saveMap(map);
    } catch (e) {
      debugPrint('[PlaybackProgress] Save error: $e');
    }
  }

  /// 获取该视频保存的上次播放位置（秒）
  static Future<int?> getProgress(String key) async {
    if (key.isEmpty) return null;
    final map = await _loadMap();
    final data = map[key];
    if (data is Map) {
      final pos = (data['pos'] as num?)?.toInt();
      if (pos != null && pos >= 10) {
        return pos;
      }
    }
    return null;
  }

  /// 清除指定视频记录
  static Future<void> clearProgress(String key) async {
    if (key.isEmpty) return;
    final map = await _loadMap();
    if (map.containsKey(key)) {
      map.remove(key);
      await _saveMap(map);
    }
  }
}
