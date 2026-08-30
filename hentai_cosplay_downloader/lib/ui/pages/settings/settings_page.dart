import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/app_config.dart';
import '../../../providers/browsing_history_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/storage_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../history/browsing_history_page.dart';
import 'resource_order_setting_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _proxyController;
  late TextEditingController _mztProxyController;
  int? _latencyMs;
  bool _isTestingProxy = false;

  bool _isTestingMzt = false;
  String? _mztLatencyText;

  @override
  void initState() {
    super.initState();
    final config = context.read<SettingsProvider>().config;
    _proxyController = TextEditingController(text: config.customProxy);
    _mztProxyController = TextEditingController(text: config.mztProxyDomains.join('\n'));
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _mztProxyController.dispose();
    super.dispose();
  }

  Future<void> _testLatency() async {
    setState(() {
      _isTestingProxy = true;
      _latencyMs = null;
    });

    final latency = await context.read<SettingsProvider>().testConnectivity();

    if (!mounted) return;

    setState(() {
      _isTestingProxy = false;
      _latencyMs = latency;
    });
  }

  Future<void> _testMztConnectivity() async {
    setState(() {
      _isTestingMzt = true;
      _mztLatencyText = null;
    });

    final latency = await context.read<SettingsProvider>().testMztBaseApiLatency();

    if (!mounted) return;

    setState(() {
      _isTestingMzt = false;
      if (latency != null) {
        _mztLatencyText = 'API 正常 ($latency ms)';
      } else {
        _mztLatencyText = 'API 连接失败，请检查网络';
      }
    });
  }

  void _saveMztProxyDomains(SettingsProvider settingsProv) {
    final lines = _mztProxyController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      settingsProv.updateMztProxyDomains(lines);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('妹子图代理域名池已保存'),
          backgroundColor: IosTheme.primaryPink,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();
    final config = settingsProv.config;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // Title
            const Text(
              '系统设置',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Storage
            _buildSectionHeader('存储与路径'),
            _buildSettingCard(
              isDark: isDark,
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
                          if (!mounted) return;
                          if (selected != null) {
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
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 2: Concurrency & Performance
            _buildSectionHeader('多线程并发'),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                children: [
                  // Pack Workers Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('同时下载图集数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${config.packWorkers} 套', style: const TextStyle(fontWeight: FontWeight.w800, color: IosTheme.primaryPink)),
                    ],
                  ),
                  Slider(
                    value: config.packWorkers.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    activeColor: IosTheme.primaryPink,
                    onChanged: (val) {
                      settingsProv.setConcurrencyLive(packWorkers: val.toInt());
                    },
                    onChangeEnd: (val) {
                      settingsProv.persistConfig();
                    },
                  ),
                  const SizedBox(height: 8),

                  // Image Workers Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('单图集图片下载并发线程', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${config.imgWorkers} 线程', style: const TextStyle(fontWeight: FontWeight.w800, color: IosTheme.primaryPink)),
                    ],
                  ),
                  Slider(
                    value: config.imgWorkers.toDouble(),
                    min: 2,
                    max: 30,
                    divisions: 28,
                    activeColor: IosTheme.primaryPink,
                    onChanged: (val) {
                      settingsProv.setConcurrencyLive(imgWorkers: val.toInt());
                    },
                    onChangeEnd: (val) {
                      settingsProv.persistConfig();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 3: Jable Settings
            _buildSectionHeader('Jable 影视设置'),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('默认清晰度偏好', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text('在线播放与下载 M3U8 多码率流时优先选取的画质', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildResolutionButton('最高画质', 'highest', config.jableResolutionPref, settingsProv),
                      const SizedBox(width: 6),
                      _buildResolutionButton('1080P', '1080p', config.jableResolutionPref, settingsProv),
                      const SizedBox(width: 6),
                      _buildResolutionButton('720P', '720p', config.jableResolutionPref, settingsProv),
                      const SizedBox(width: 6),
                      _buildResolutionButton('480P', '480p', config.jableResolutionPref, settingsProv),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jable 并发下载视频数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${config.jableWorkers} 部', style: const TextStyle(fontWeight: FontWeight.w800, color: IosTheme.primaryPink)),
                    ],
                  ),
                  Slider(
                    value: config.jableWorkers.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    activeColor: IosTheme.primaryPink,
                    onChanged: (val) {
                      settingsProv.setJableWorkersLive(val.toInt());
                    },
                    onChangeEnd: (val) {
                      settingsProv.persistConfig();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 4: Network & Proxy
            _buildSectionHeader('网络与全局代理设置'),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自定义 HTTP / SOCKS 代理（可选）',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '若目标网站在当前网络受限，可填写本地代理端口，如 127.0.0.1:7890（留空为直连）',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _proxyController,
                          placeholder: '例如: 127.0.0.1:7890',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                          onSubmitted: (val) {
                            settingsProv.setCustomProxy(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      BouncingButton(
                        onTap: () {
                          settingsProv.setCustomProxy(_proxyController.text);
                          _testLatency();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('保存并测速', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  if (_isTestingProxy || _latencyMs != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_isTestingProxy) ...[
                          const CupertinoActivityIndicator(radius: 7),
                          const SizedBox(width: 6),
                          const Text('正在测试网站连接延迟...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ] else if (_latencyMs != null) ...[
                          Icon(
                            _latencyMs! < 1000 ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.exclamationmark_circle_fill,
                            size: 16,
                            color: _latencyMs! < 1000 ? IosTheme.primaryGreen : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '连接成功！延迟: ${_latencyMs}ms',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _latencyMs! < 1000 ? IosTheme.primaryGreen : Colors.orange,
                            ),
                          ),
                        ] else ...[
                          const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          const Text('连接失败，请检查网络或代理地址', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 4: MZT Proxy Domain Pool
            _buildSectionHeader('妹子图代理域名池与诊断'),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MZT 相对路径代理节点池 (轮询与故障转移)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '针对妹子图相对路径，下载器将按序轮询以下节点并在 404 时自动切换：',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mztProxyController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      BouncingButton(
                        onTap: () => _saveMztProxyDomains(settingsProv),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('保存域名池', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BouncingButton(
                        onTap: () {
                          settingsProv.resetMztProxyDomains();
                          _mztProxyController.text = kDefaultMztProxyDomains.join('\n');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('恢复默认', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ),
                      const Spacer(),
                      BouncingButton(
                        onTap: _testMztConnectivity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.waveform_path, size: 13, color: IosTheme.primaryGreen),
                              const SizedBox(width: 4),
                              Text(
                                _isTestingMzt ? '测速中...' : '测试API',
                                style: const TextStyle(color: IosTheme.primaryGreen, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_mztLatencyText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _mztLatencyText!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _mztLatencyText!.contains('正常') ? IosTheme.primaryGreen : Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section: Online Resources Sort Order & History
            _buildSectionHeader('在线资源管理'),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Browsing History Entrance
                  Builder(
                    builder: (context) {
                      final historyCount = context.select<BrowsingHistoryProvider, int>(
                        (p) => p.totalCount,
                      );
                      return Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.22 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.clock_fill, color: Color(0xFF007AFF), size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '在线资源浏览历史',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  historyCount > 0
                                      ? '已记录 $historyCount 条看过的图集与视频'
                                      : '暂无浏览记录，点开资源将自动记录',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          BouncingButton(
                            onTap: () => BrowsingHistoryPage.open(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('查看历史', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                                  SizedBox(width: 2),
                                  Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 12),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, thickness: 0.5),
                  ),

                  // 2. Custom Sort Order Entrance
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink.withValues(alpha: isDark ? 0.22 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.square_list_fill, color: IosTheme.primaryPink, size: 19),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '自定义站点排序',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '长按拖拽调整【在线资源】顶部标签与页面排列顺序',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      BouncingButton(
                        onTap: () => ResourceOrderSettingPage.open(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: IosTheme.primaryPink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('去排序', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                              SizedBox(width: 2),
                              Icon(CupertinoIcons.chevron_right, color: Colors.white, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section 4: Theme
            _buildSectionHeader('主题与外观'),
            _buildSettingCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('外观模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildThemeModeButton('跟随系统', 'system', config.themeMode, settingsProv),
                      const SizedBox(width: 8),
                      _buildThemeModeButton('浅色模式', 'light', config.themeMode, settingsProv),
                      const SizedBox(width: 8),
                      _buildThemeModeButton('深色模式', 'dark', config.themeMode, settingsProv),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('底栏与胶囊透明度', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      Text(
                        '${(config.navBarOpacity * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: IosTheme.primaryPink),
                      ),
                    ],
                  ),
                  Slider(
                    value: config.navBarOpacity.clamp(0.1, 1.0),
                    min: 0.1,
                    max: 1.0,
                    divisions: 18,
                    activeColor: IosTheme.primaryPink,
                    onChanged: (val) {
                      settingsProv.setNavBarOpacityLive(val);
                    },
                    onChangeEnd: (val) {
                      settingsProv.persistConfig();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 5: App Info
            Center(
              child: Column(
                children: [
                  const Text(
                    'Hentai Cosplay Downloader v1.0.0',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '数据来源: hentai-cosplay-xxx.com',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
          width: 0.6,
        ),
      ),
      child: child,
    );
  }

  Widget _buildThemeModeButton(String label, String mode, String currentMode, SettingsProvider settingsProv) {
    final isSelected = mode == currentMode;

    return Expanded(
      child: BouncingButton(
        onTap: () => settingsProv.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? IosTheme.primaryPink : Colors.grey.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResolutionButton(String label, String pref, String currentPref, SettingsProvider settingsProv) {
    final isSelected = pref == currentPref;

    return Expanded(
      child: BouncingButton(
        onTap: () => settingsProv.setJableResolutionPref(pref),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? IosTheme.primaryPink : Colors.grey.withAlpha(80),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
