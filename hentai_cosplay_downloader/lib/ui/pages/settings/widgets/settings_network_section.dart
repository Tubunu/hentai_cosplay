import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Network & Proxy Section
        const SettingsSectionHeader(title: '网络与全局代理设置'),
        SettingsCard(
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
                    value: settingsProv.config.allowInsecureCertificates,
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

        // MZT Proxy Domain Pool Section
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
}
