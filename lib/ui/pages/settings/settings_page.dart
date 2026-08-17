import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/app_config.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/config_service.dart';
import '../../../services/storage_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/frosted_glass.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _proxyController;
  bool _isTestingApi = false;
  String? _apiLatencyText;

  @override
  void initState() {
    super.initState();
    final config = context.read<SettingsProvider>().config;
    _proxyController = TextEditingController(text: config.proxyDomains.join('\n'));
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
  }

  void _chooseSaveDirectory(BuildContext context, SettingsProvider settingsProv) async {
    // Check & request storage permission
    final hasPerm = await StorageService.requestStoragePermission();
    if (!hasPerm && Platform.isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未获得所有文件访问权限，可能无法保存至自定义外部目录。'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final writable = await StorageService.isDirectoryWritable(selectedDirectory);
        if (!writable) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('选取的目录不可写，请检查系统存储权限！'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        await settingsProv.updateSavePath(selectedDirectory);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('保存路径已更新！'),
              backgroundColor: IosTheme.primaryPink,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录出错: $e')),
        );
      }
    }
  }

  void _resetDefaultPath(BuildContext context, SettingsProvider settingsProv) async {
    final defaultPath = await ConfigService.getDefaultDownloadPath();
    await settingsProv.updateSavePath(defaultPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置为默认下载路径')),
      );
    }
  }

  void _testConnectivity() async {
    setState(() {
      _isTestingApi = true;
      _apiLatencyText = null;
    });

    final stopwatch = Stopwatch()..start();
    final res = await ApiService.fetchPageData(page: 1, pageSize: 1);
    stopwatch.stop();

    setState(() {
      _isTestingApi = false;
      if (res != null) {
        _apiLatencyText = 'API 正常 (${stopwatch.elapsedMilliseconds} ms)';
      } else {
        _apiLatencyText = 'API 连接失败，请检查网络';
      }
    });
  }

  void _saveProxyDomains(SettingsProvider settingsProv) {
    final lines = _proxyController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      settingsProv.updateProxyDomains(lines);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('代理域名池已保存'),
          backgroundColor: IosTheme.primaryPink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final config = settingsProv.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Ambient Mesh Glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(gradient: IosTheme.ambientMesh),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Large Hero Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREFERENCES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: IosTheme.primaryPink.withOpacity(0.9),
                          ),
                        ),
                        const Text(
                          '系统设置',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Group 1: Storage & Path Settings
                _buildGroupHeader('存储与路径'),
                SliverToBoxAdapter(
                  child: _buildCardContainer(
                    context,
                    isDark,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(CupertinoIcons.folder_fill, color: IosTheme.primaryPink, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  '下载保存路径',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                config.savePath.isNotEmpty ? config.savePath : '未设置路径',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: IosTheme.secondaryText(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: IosTheme.primaryPink,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(CupertinoIcons.folder_badge_plus, size: 16),
                                  label: const Text('选择目录', style: TextStyle(fontWeight: FontWeight.w700)),
                                  onPressed: () => _chooseSaveDirectory(context, settingsProv),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () => _resetDefaultPath(context, settingsProv),
                                  child: const Text('重置默认'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Group 2: Concurrency & Performance
                _buildGroupHeader('并发与下载参数'),
                SliverToBoxAdapter(
                  child: _buildCardContainer(
                    context,
                    isDark,
                    children: [
                      // Pack Workers Slider
                      _buildSliderRow(
                        title: '图包并发数',
                        value: config.packWorkers.toDouble(),
                        min: 1,
                        max: 30,
                        unit: '个',
                        onChanged: (v) => settingsProv.updateWorkers(packWorkers: v.toInt()),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Image Workers Slider
                      _buildSliderRow(
                        title: '图片并发数 (每包)',
                        value: config.imgWorkers.toDouble(),
                        min: 1,
                        max: 50,
                        unit: '线程',
                        onChanged: (v) => settingsProv.updateWorkers(imgWorkers: v.toInt()),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Retry Count Slider
                      _buildSliderRow(
                        title: '单链接失败重试次数',
                        value: config.retryCount.toDouble(),
                        min: 0,
                        max: 10,
                        unit: '次',
                        onChanged: (v) => settingsProv.updateWorkers(retryCount: v.toInt()),
                      ),
                    ],
                  ),
                ),

                // Group 3: Proxy Domains Pool
                _buildGroupHeader('代理域名池 (轮询策略)'),
                SliverToBoxAdapter(
                  child: _buildCardContainer(
                    context,
                    isDark,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '针对以 /file/ 开头的相对路径链接，下载器将按序轮询以下域名：',
                              style: TextStyle(fontSize: 12, color: IosTheme.secondaryText(context)),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _proxyController,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: IosTheme.primaryPink,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => _saveProxyDomains(settingsProv),
                                  child: const Text('保存域名池', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () {
                                    settingsProv.resetProxyDomains();
                                    _proxyController.text = kDefaultProxyDomains.join('\n');
                                  },
                                  child: const Text('恢复默认'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Group 4: Auto Archiving
                _buildGroupHeader('自动归档与分类'),
                SliverToBoxAdapter(
                  child: _buildCardContainer(
                    context,
                    isDark,
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text('下载完成后自动归档', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('按作者自动将图包整理至 archive/ 目录', style: TextStyle(fontSize: 12)),
                        value: config.autoArchive,
                        activeColor: IosTheme.primaryPink,
                        onChanged: (v) => settingsProv.updateAutoArchive(v, config.archiveStrategy),
                      ),
                    ],
                  ),
                ),

                // Group 5: Appearance
                _buildGroupHeader('外观与主题'),
                SliverToBoxAdapter(
                  child: _buildCardContainer(
                    context,
                    isDark,
                    children: [
                      ListTile(
                        leading: const Icon(CupertinoIcons.moon_stars, color: IosTheme.primaryPink),
                        title: const Text('主题模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: DropdownButton<String>(
                          value: config.themeMode,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                            DropdownMenuItem(value: 'light', child: Text('浅色模式')),
                            DropdownMenuItem(value: 'dark', child: Text('深色模式')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              settingsProv.updateThemeMode(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Group 6: Diagnostics & About
                _buildGroupHeader('网络连通与关于'),
                SliverToBoxAdapter(
                  child: _buildCardContainer(
                    context,
                    isDark,
                    children: [
                      ListTile(
                        leading: const Icon(CupertinoIcons.waveform_path, color: IosTheme.systemGreen),
                        title: const Text('API 服务器连通性测试', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          _apiLatencyText ?? 'https://mzt.111404.xyz',
                          style: TextStyle(
                            fontSize: 12,
                            color: _apiLatencyText != null && _apiLatencyText!.contains('正常')
                                ? IosTheme.systemGreen
                                : IosTheme.secondaryText(context),
                          ),
                        ),
                        trailing: _isTestingApi
                            ? const CupertinoActivityIndicator()
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: IosTheme.systemGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: _testConnectivity,
                                child: const Text('测试'),
                              ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(CupertinoIcons.info_circle, color: Colors.grey),
                        title: const Text('版本信息', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: Text(
                          'v1.0.0 (Apple Music Edition)',
                          style: TextStyle(color: IosTheme.secondaryText(context), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.watch<DownloadProvider>().hasActiveOrPausedTasks ? 210 : 130,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: IosTheme.primaryPink,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer(BuildContext context, bool isDark, {required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FrostedGlass(
        borderRadius: 20,
        blur: 15,
        backgroundColor: isDark ? const Color(0x8824242A) : const Color(0xEEFFFFFF),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                '${value.toInt()} $unit',
                style: const TextStyle(fontWeight: FontWeight.w800, color: IosTheme.primaryPink, fontSize: 14),
              ),
            ],
          ),
          Slider.adaptive(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: IosTheme.primaryPink,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
