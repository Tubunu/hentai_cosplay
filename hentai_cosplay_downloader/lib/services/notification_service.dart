import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _downloadNotificationId = 9999;
  static const int _completeNotificationId = 10000;
  static const String _channelId = 'hentai_cosplay_download_channel';
  static const String _channelName = 'Hentai Cosplay 下载监控';
  static const String _channelDesc = '实时展示图片图集的后台下载进度与速率通知';

  static bool _isInitialized = false;
  static int _lastNotificationUpdateTime = 0;

  /// Initialize local notification settings for Android and iOS
  static Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
      if (Platform.isIOS || Platform.isAndroid) {
        await requestNotificationPermission();
      }
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  /// Request notification permission on Android 13+ and iOS
  static Future<bool> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (status.isGranted) return true;
        final res = await Permission.notification.request();
        return res.isGranted;
      } else if (Platform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Request notification permission error: $e');
    }
    return true;
  }

  /// Show or update the real-time download progress notification on Android & iOS
  static Future<void> updateProgressNotification({
    required String title,
    required double progress, // 0.0 ~ 1.0
    required String speed,
    required int finishedCount,
    required int totalCount,
    bool isPaused = false,
  }) async {
    if (!_isInitialized) await init();

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!isPaused && progress < 1.0 && (now - _lastNotificationUpdateTime < 500)) {
      return;
    }
    _lastNotificationUpdateTime = now;

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
      color: const Color(0xFFFF2D55),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // Silent update to prevent ringing every second
      threadIdentifier: 'hc_download_progress',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

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

  /// Show single album completed notification on both Android & iOS
  static Future<void> showAlbumCompleted({
    required String title,
    required int imagesCount,
  }) async {
    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
      color: Color(0xFFFF2D55),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      final notifId = (title.hashCode & 0x7FFFFFFF) % 5000 + 1000;
      await _notificationsPlugin.show(
        notifId,
        '✅ 图集下载完成',
        '《$title》已成功下载 $imagesCount 张图片',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Show album completed notification error: $e');
    }
  }

  /// Show completed notification on both Android & iOS
  static Future<void> showDownloadCompleted({
    required int albumsCount,
    required int imagesCount,
    required double durationSec,
  }) async {
    if (!_isInitialized) await init();

    // Cancel ongoing progress notification first
    await cancelNotification();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      color: Color(0xFF34C759),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        _completeNotificationId,
        '🎉 所有图集下载任务已完成！',
        '已下载 $albumsCount 套图集，共 $imagesCount 张图片 (耗时 ${durationSec.toStringAsFixed(1)}s)',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Show complete notification error: $e');
    }
  }

  /// Cancel download progress notification
  static Future<void> cancelNotification() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(_downloadNotificationId);
    } catch (_) {}
  }
}
