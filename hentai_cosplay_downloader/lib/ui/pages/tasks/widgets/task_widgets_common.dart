import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/download_task.dart';
import 'package:hentai_cosplay_downloader/models/jable_task.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class TaskStatusBadge extends StatelessWidget {
  final TaskStatus status;

  const TaskStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case TaskStatus.completed:
        color = IosTheme.primaryGreen;
        label = '已完成';
        break;
      case TaskStatus.downloading:
        color = IosTheme.primaryPink;
        label = '下载中';
        break;
      case TaskStatus.queued:
        color = IosTheme.primaryBlue;
        label = '等待中';
        break;
      case TaskStatus.paused:
        color = Colors.orange;
        label = '已暂停';
        break;
      case TaskStatus.failed:
        color = Colors.red;
        label = '失败';
        break;
      default:
        color = Colors.grey;
        label = '未开始';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class JableStatusBadge extends StatelessWidget {
  final JableDownloadStatus status;

  const JableStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case JableDownloadStatus.completed:
        color = IosTheme.primaryGreen;
        label = '已完成';
        break;
      case JableDownloadStatus.downloading:
        color = IosTheme.primaryPink;
        label = '下载中';
        break;
      case JableDownloadStatus.merging:
        color = Colors.orange;
        label = '合并中';
        break;
      case JableDownloadStatus.waiting:
        color = IosTheme.primaryBlue;
        label = '等待中';
        break;
      case JableDownloadStatus.paused:
        color = Colors.orange;
        label = '已暂停';
        break;
      case JableDownloadStatus.failed:
        color = Colors.red;
        label = '失败';
        break;
      default:
        color = Colors.grey;
        label = '取消';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TaskActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const TaskActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
