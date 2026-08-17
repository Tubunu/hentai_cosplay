import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _downloadNotificationId = 8888;
  static const String _channelId = 'mzt_download_channel';
  static const String _channelName = 'Mzt 下载进度监控';
  static const String _channelDesc = '实时展示图片图包的后台下载进度与速率通知';

  static bool _isInitialized = false;

  /// Initialize local notification settings
  static Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  /// Request notification permission on Android 13+
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final res = await Permission.notification.request();
    return res.isGranted;
  }

  /// Show or update the real-time download progress notification
  static Future<void> updateProgressNotification({
    required String title,
    required double progress, // 0.0 ~ 1.0
    required String speed,
    required int finishedCount,
    required int totalCount,
    bool isPaused = false,
  }) async {
    if (!_isInitialized) await init();

    final percent = (progress * 100).toInt().clamp(0, 100);
    final statusPrefix = isPaused ? '[已暂停] ' : '';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low, // Use low importance to avoid continuous sound/vibration on updates
      priority: Priority.low,
      ongoing: !isPaused,
      autoCancel: false,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      color: const Color(0xFFFA2D55),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        _downloadNotificationId,
        '$statusPrefix正在下载 ($percent% • $speed)',
        '$title ($finishedCount/$totalCount)',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Show progress notification error: $e');
    }
  }

  /// Show completed notification
  static Future<void> showDownloadCompleted({
    required int packsCount,
    required int imagesCount,
    required double durationSec,
  }) async {
    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      color: const Color(0xFF34C759),
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        _downloadNotificationId,
        '🎉 所有下载任务已完成！',
        '已下载 $packsCount 个图包，共 $imagesCount 张图片 (耗时 ${durationSec.toStringAsFixed(1)}s)',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Show complete notification error: $e');
    }
  }

  /// Cancel download notification
  static Future<void> cancelNotification() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(_downloadNotificationId);
    } catch (_) {}
  }
}
