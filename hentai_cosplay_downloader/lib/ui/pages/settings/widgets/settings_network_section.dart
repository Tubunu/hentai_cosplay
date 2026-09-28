import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/services/proxy/libbox_manager.dart';
import 'package:hentai_cosplay_downloader/services/proxy/site_registry.dart';
import 'package:hentai_cosplay_downloader/ui/pages/chromego/chromego_home_page.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:provider/provider.dart';
import 'settings_shared_widgets.dart';

class SettingsNetworkSection extends StatefulWidget {
  const SettingsNetworkSection({super.key});

  @override
  State<SettingsNetworkSection> createState() => _SettingsNetworkSectionState();
}

class _SettingsNetworkSectionState extends State<SettingsNetworkSection> {
  late TextEditingController _proxyController;
  late TextEditingController _mztProxyController;
  late TextEditingController _portController;
  final TextEditingController _siteSearchController = TextEditingController();

  int? _latencyMs;
  bool _isTestingProxy = false;

  bool _isTestingMzt = false;
  String? _mztLatencyText;

  String _siteFilterTab = 'all'; // 'all', 'proxied', 'direct'
  String _siteSearchQuery = '';

  @override
  void initState() {
    super.initState();
    final config = context.read<SettingsProvider>().config;
    _proxyController = TextEditingController(text: config.customProxy);
    _mztProxyController = TextEditingController(text: config.mztProxyDomains.join('\n'));
    _portController = TextEditingController(text: config.builtinProxyPort.toString());
  }

  @override
  void dispose() {
    _proxyController.dispose();
    _mztProxyController.dispose();
    _portController.dispose();
    _siteSearchController.dispose();
    super.dispose();
  }

  Future<void> _testLatency() async {
    setState(() {
      _isTestingProxy = true;
      _latencyMs = null;
    });

    final latency = await context.read<SettingsProvider>().testConnectivity(_proxyController.text);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ChromeGo Node Extractor Entry Card
        SettingsCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const ChromeGoHomePage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0061A4), Color(0xFF00A2FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0061A4).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.paperplane_fill,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ChromeGo 节点提取器',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: IosTheme.primaryPink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '内置工具',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: IosTheme.primaryPink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '多源免费节点提取 • TCP测速 • 一键设置为应用内置代理',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Section 1: Proxy Mode Selection
        const SettingsSectionHeader(title: '代理核心与运行模式'),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '代理连接方式',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 4),
              const Text(
                '推荐使用应用内置代理，无需外部 VPN 或第三方代理客户端即可畅连',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // Segmented Mode Selector
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildModeButton(
                      context,
                      title: '内置内核',
                      badge: '推荐',
                      isSelected: config.proxyMode == AppProxyMode.builtin,
                      onTap: () => settingsProv.setProxyMode(AppProxyMode.builtin),
                    ),
                    _buildModeButton(
                      context,
                      title: '外部端口',
                      isSelected: config.proxyMode == AppProxyMode.custom,
                      onTap: () => settingsProv.setProxyMode(AppProxyMode.custom),
                    ),
                    _buildModeButton(
                      context,
                      title: '完全直连',
                      isSelected: config.proxyMode == AppProxyMode.direct,
                      onTap: () => settingsProv.setProxyMode(AppProxyMode.direct),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mode 1: Builtin proxy card
              if (config.proxyMode == AppProxyMode.builtin)
                _buildBuiltinProxyCard(context, settingsProv, isDark),

              // Mode 2: Custom proxy configuration
              if (config.proxyMode == AppProxyMode.custom)
                _buildCustomProxyCard(context, settingsProv, isDark),

              // Mode 3: Direct mode info
              if (config.proxyMode == AppProxyMode.direct)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.info_circle_fill, color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '当前处于完全直连模式，应用内请求均不经过代理。如遇目标站点连接超时，请切换为内置内核或外部代理。',
                          style: TextStyle(fontSize: 11.5, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '允许自签/不安全 SSL 证书',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '仅在使用抓包调试代理（如 Charles、Proxyman）时开启，正常使用请保持关闭以防中间人攻击',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoSwitch(
                    value: config.allowInsecureCertificates,
                    activeTrackColor: Colors.orangeAccent,
                    onChanged: (val) {
                      settingsProv.setAllowInsecureCertificates(val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section 2: Routing Strategy & Per-Site Toggles (Only when proxy is not Direct)
        if (config.proxyMode != AppProxyMode.direct) ...[
          const SettingsSectionHeader(title: '代理分流策略与站点开关'),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '应用内网络分流策略',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  '选择是为每个站点单独设置代理，还是让所有请求统一经过代理',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Routing Strategy Selector
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildModeButton(
                        context,
                        title: '智能分站点代理',
                        badge: '推荐',
                        isSelected: config.proxyRoutingStrategy == ProxyRoutingStrategy.perSite,
                        onTap: () => settingsProv.setProxyRoutingStrategy(ProxyRoutingStrategy.perSite),
                      ),
                      _buildModeButton(
                        context,
                        title: '全局走代理',
                        isSelected: config.proxyRoutingStrategy == ProxyRoutingStrategy.global,
                        onTap: () => settingsProv.setProxyRoutingStrategy(ProxyRoutingStrategy.global),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (config.proxyRoutingStrategy == ProxyRoutingStrategy.global)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(CupertinoIcons.globe, color: Colors.orange, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '当前为全局代理模式：所有站点（包含妹子图、HC图集等国内源）均强制走代理。建议使用“智能分站点代理”以降低节点流量消耗。',
                            style: TextStyle(fontSize: 11.5, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildPerSiteTogglePanel(context, settingsProv, isDark),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Section 3: MZT Proxy Domain Pool Section
        const SettingsSectionHeader(title: '妹子图代理域名池与诊断'),
        SettingsCard(
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
      ],
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String title,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF3A3A3C) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: IosTheme.primaryPink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuiltinProxyCard(BuildContext context, SettingsProvider settingsProv, bool isDark) {
    return ListenableBuilder(
      listenable: LibboxManager.instance,
      builder: (context, _) {
        final mgr = LibboxManager.instance;
        final isRunning = mgr.isRunning;
        final node = mgr.activeNode;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRunning
                  ? IosTheme.primaryGreen.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Row
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? IosTheme.primaryGreen : Colors.grey,
                      boxShadow: isRunning
                          ? [
                              BoxShadow(
                                color: IosTheme.primaryGreen.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRunning ? '内置内核运行中' : '内置内核就绪 (免VPN权限/无钥匙图标)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isRunning ? IosTheme.primaryGreen : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  const Spacer(),
                  if (isRunning && mgr.latencyMs != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: IosTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${mgr.latencyMs} ms',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: IosTheme.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (isRunning && node != null) ...[
                Text(
                  '当前节点: ${node.cleanName()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '协议: ${node.protocol.toUpperCase()} • 地址: ${node.server}:${node.port}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 10),
              ] else ...[
                const Text(
                  '应用内回环地址: 127.0.0.1:20808 • 纯应用内分流',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 10),
              ],

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: BouncingButton(
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const ChromeGoHomePage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0061A4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.paperplane_fill, size: 13, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              isRunning ? '切换代理节点' : '前往提取并连接节点',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isRunning) ...[
                    const SizedBox(width: 8),
                    BouncingButton(
                      onTap: () => mgr.testActiveNodeLatency(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('测速', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BouncingButton(
                      onTap: () => mgr.stop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '断开',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomProxyCard(BuildContext context, SettingsProvider settingsProv, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

  Widget _buildPerSiteTogglePanel(BuildContext context, SettingsProvider settingsProv, bool isDark) {
    final allSites = SiteRegistry.allSites;
    final toggles = settingsProv.config.siteProxyToggles;

    final proxiedCount = allSites.where((s) => toggles[s.key] ?? s.defaultProxy).length;
    final directCount = allSites.length - proxiedCount;

    // Filter sites according to search and tab
    final query = _siteSearchQuery.toLowerCase().trim();
    final filteredSites = allSites.where((site) {
      final isProxied = toggles[site.key] ?? site.defaultProxy;
      if (_siteFilterTab == 'proxied' && !isProxied) return false;
      if (_siteFilterTab == 'direct' && isProxied) return false;

      if (query.isNotEmpty) {
        final matchesName = site.displayName.toLowerCase().contains(query);
        final matchesKey = site.key.toLowerCase().contains(query);
        final matchesDomain = site.primaryDomains.any((d) => d.toLowerCase().contains(query));
        return matchesName || matchesKey || matchesDomain;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with count & batch actions
        Row(
          children: [
            Text(
              '站点代理开关 ($proxiedCount/${allSites.length} 开启)',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            // Batch Buttons
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => settingsProv.setAllSiteProxyToggles(true),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('全开', style: TextStyle(fontSize: 11.5, color: IosTheme.primaryPink, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => settingsProv.setAllSiteProxyToggles(false),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('全关', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => settingsProv.resetSiteProxyToggles(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text('默认', style: TextStyle(fontSize: 11.5, color: Colors.blue)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Bar & Filter chips
        Row(
          children: [
            Expanded(
              child: CupertinoSearchTextField(
                controller: _siteSearchController,
                placeholder: '搜索站点名称或域名...',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                onChanged: (val) {
                  setState(() {
                    _siteSearchQuery = val;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter tabs: 全部 | 代理 | 直连
        Row(
          children: [
            _buildSiteFilterChip('全部 (${allSites.length})', 'all', isDark),
            const SizedBox(width: 6),
            _buildSiteFilterChip('走代理 ($proxiedCount)', 'proxied', isDark),
            const SizedBox(width: 6),
            _buildSiteFilterChip('直连 ($directCount)', 'direct', isDark),
          ],
        ),
        const SizedBox(height: 8),

        // Scrollable list container of 38+ sites
        Container(
          constraints: const BoxConstraints(maxHeight: 320),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 0.5,
            ),
          ),
          child: filteredSites.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('未找到符合条件的站点', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: filteredSites.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    final site = filteredSites[index];
                    final isEnabled = toggles[site.key] ?? site.defaultProxy;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          // Category tag or initial
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? IosTheme.primaryPink.withValues(alpha: 0.15)
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              site.displayName.characters.first,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? IosTheme.primaryPink : Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        site.displayName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isEnabled
                                            ? Colors.green.withValues(alpha: 0.12)
                                            : Colors.blue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isEnabled ? '代理' : '直连',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isEnabled ? Colors.green : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  site.primaryDomains.take(2).join(', '),
                                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: 0.8,
                            child: CupertinoSwitch(
                              value: isEnabled,
                              activeTrackColor: IosTheme.primaryPink,
                              onChanged: (val) {
                                settingsProv.setSiteProxyToggle(site.key, val);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSiteFilterChip(String label, String tabKey, bool isDark) {
    final isSelected = _siteFilterTab == tabKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _siteFilterTab = tabKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? IosTheme.primaryPink.withValues(alpha: 0.18)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? IosTheme.primaryPink : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? IosTheme.primaryPink
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
