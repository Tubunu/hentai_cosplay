import 'dart:collection';
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warn,
  error,
  success,
}

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formattedTime {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() {
    final levelStr = level.name.toUpperCase().padRight(5);
    var res = '[$formattedTime] [$levelStr] [$tag] $message';
    if (error != null) {
      res += '\n  Error: $error';
    }
    return res;
  }
}

class AppLogger extends ChangeNotifier {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const int _maxLogs = 500;
  final ListQueue<LogEntry> _logs = ListQueue<LogEntry>();

  List<LogEntry> get logs => _logs.toList();

  static void d(String tag, String message) => _instance._log(LogLevel.debug, tag, message);
  static void i(String tag, String message) => _instance._log(LogLevel.info, tag, message);
  static void w(String tag, String message, [dynamic error]) => _instance._log(LogLevel.warn, tag, message, error);
  static void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) =>
      _instance._log(LogLevel.error, tag, message, error, stackTrace);
  static void s(String tag, String message) => _instance._log(LogLevel.success, tag, message);

  void _log(LogLevel level, String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    if (_logs.length >= _maxLogs) {
      _logs.removeFirst();
    }
    _logs.addLast(entry);

    debugPrint(entry.toString());
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  String getAllLogsFormatted([String? tagFilter]) {
    final filtered = tagFilter != null && tagFilter.isNotEmpty && tagFilter != '全部'
        ? _logs.where((l) => l.tag.contains(tagFilter) || l.message.contains(tagFilter))
        : _logs;
    return filtered.map((l) => l.toString()).join('\n');
  }
}
