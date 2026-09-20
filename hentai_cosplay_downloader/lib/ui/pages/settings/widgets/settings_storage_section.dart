import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/services/storage_service.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:provider/provider.dart';
import 'settings_shared_widgets.dart';

class SettingsStorageSection extends StatefulWidget {
  const SettingsStorageSection({super.key});

  @override
  State<SettingsStorageSection> createState() => _SettingsStorageSectionState();
}

class _SettingsStorageSectionState extends State<SettingsStorageSection> {
  int? _cacheBytes;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final size = await StorageService.getCacheSize();
    if (mounted) {
      setState(() {
        _cacheBytes = size;
      });
    }
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;
    setState(() => _isClearing = true);
    await StorageService.clearCache();
    await _loadCacheSize();
    if (mounted) {
      setState(() => _isClearing = false);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已成功清理临时缓存空间'),
          backgroundColor: IosTheme.primaryPink,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();
    final config = settingsProv.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: '存储与路径'),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.folder_badge_plus, size: 20, color: IosTheme.primaryPink),
                  const SizedBox(width: 8),
                  const Text('图片下载保存目录', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  BouncingButton(
                    onTap: () async {
                      final selected = await StorageService.pickSaveDirectory();
                      if (context.mounted && selected != null) {
                        settingsProv.setSavePath(selected);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryPink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('选择目录', style: TextStyle(color: IosTheme.primaryPink, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.savePath.isNotEmpty ? config.savePath : '未设置路径（点击选择）',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(CupertinoIcons.info_circle_fill, size: 13, color: IosTheme.primaryCyan),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '已启用 iOS【文件】App 共享，可在「文件 -> 我的 iPhone -> Hentai Cosplay Downloader」直接查看和管理。',
                                style: TextStyle(fontSize: 11, color: IosTheme.primaryCyan, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Auto Archive Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('按作者名自动归档', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('下载时自动创建 archive/<作者>/<图集> 目录', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  CupertinoSwitch(
                    activeTrackColor: IosTheme.primaryPink,
                    value: config.autoArchive,
                    onChanged: (val) {
                      settingsProv.setAutoArchive(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
              const SizedBox(height: 14),

              // Cache Size & Clear Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(CupertinoIcons.trash, size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text('应用临时缓存', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _cacheBytes != null ? '当前占用: ${_formatBytes(_cacheBytes!)}' : '正在计算中...',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  BouncingButton(
                    onTap: _isClearing ? null : _clearCache,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isClearing
                          ? const CupertinoActivityIndicator(radius: 7)
                          : const Text(
                              '一键清理',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
