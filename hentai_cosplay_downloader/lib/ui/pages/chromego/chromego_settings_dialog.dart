import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/chromego/chromego_sub_server.dart';

/// Settings and LAN Subscription server dialog.
class ChromeGoSettingsDialog extends StatefulWidget {
  final bool preferMirror;
  final ValueChanged<bool> onPreferMirrorChanged;
  final LocalSubServer subServer;
  final VoidCallback onServerToggled;

  const ChromeGoSettingsDialog({
    super.key,
    required this.preferMirror,
    required this.onPreferMirrorChanged,
    required this.subServer,
    required this.onServerToggled,
  });

  @override
  State<ChromeGoSettingsDialog> createState() => _ChromeGoSettingsDialogState();
}

class _ChromeGoSettingsDialogState extends State<ChromeGoSettingsDialog> {
  String _lanIp = '获取中...';

  @override
  void initState() {
    super.initState();
    _fetchLanIp();
  }

  Future<void> _fetchLanIp() async {
    final ip = await LocalSubServer.getLanIp();
    if (mounted) {
      setState(() => _lanIp = ip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subUrl = 'http://$_lanIp:${widget.subServer.actualPort}/sub';
    final clashUrl = 'http://$_lanIp:${widget.subServer.actualPort}/clash';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '设置与局域网订阅',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Network source
              Text('网络拉取源', style: theme.textTheme.titleSmall),
              SwitchListTile(
                title: const Text('优先使用国内镜像源'),
                subtitle: const Text('www.67867867.xyz (免翻墙，更稳定)'),
                value: widget.preferMirror,
                onChanged: (val) {
                  widget.onPreferMirrorChanged(val);
                  setState(() {});
                },
              ),
              const Divider(),

              // LAN Sub Server
              Text('内置 Wi-Fi 订阅服务器', style: theme.textTheme.titleSmall),
              SwitchListTile(
                title: Text(widget.subServer.isRunning ? '服务运行中 (端口: ${widget.subServer.actualPort})' : '服务已停止'),
                subtitle: Text('局域网 IP: $_lanIp'),
                value: widget.subServer.isRunning,
                onChanged: (_) {
                  widget.onServerToggled();
                  setState(() {});
                },
              ),

              if (widget.subServer.isRunning) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
                      ],
                    ),
                    child: QrImageView(
                      data: subUrl,
                      version: QrVersions.auto,
                      size: 160,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '同 Wi-Fi 手机/平板使用小火箭直接扫码即可订阅',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制订阅 URL'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: subUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已复制订阅地址: $subUrl')),
                        );
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制 Clash 配置 URL'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: clashUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已复制 Clash 地址: $clashUrl')),
                        );
                      },
                    ),
                  ],
                ),
              ],

              const Divider(),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'ChromeGo 节点提取器 (内置工具)',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
