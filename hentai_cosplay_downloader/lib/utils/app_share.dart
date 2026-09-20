import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class AppShare {
  /// 分享文本内容，自动获取 UI 坐标作为 iPad/macOS 弹出位置
  static Future<void> share(
    BuildContext context,
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final box = context.mounted ? (context.findRenderObject() as RenderBox?) : null;
    final rect = sharePositionOrigin ?? (box != null ? (box.localToGlobal(Offset.zero) & box.size) : null);
    
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: rect,
    );
  }

  /// 分享文件，自动获取 UI 坐标作为 iPad/macOS 弹出位置
  static Future<void> shareXFiles(
    BuildContext context,
    List<XFile> files, {
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final box = context.mounted ? (context.findRenderObject() as RenderBox?) : null;
    final rect = sharePositionOrigin ?? (box != null ? (box.localToGlobal(Offset.zero) & box.size) : null);

    await Share.shareXFiles(
      files,
      text: text,
      subject: subject,
      sharePositionOrigin: rect,
    );
  }
}
