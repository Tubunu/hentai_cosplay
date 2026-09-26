import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/chromego/proxy_node.dart';
import '../../../services/chromego/chromego_fetcher.dart';
import '../../../services/chromego/chromego_exporter.dart';
import '../../../services/chromego/chromego_cache_service.dart';
import '../../../services/chromego/chromego_ping_service.dart';
import '../../../services/chromego/chromego_sub_server.dart';
import 'chromego_qr_dialog.dart';
import 'chromego_settings_dialog.dart';

class ChromeGoHomePage extends StatefulWidget {
  const ChromeGoHomePage({super.key});

  @override
  State<ChromeGoHomePage> createState() => _ChromeGoHomePageState();
}

class _ChromeGoHomePageState extends State<ChromeGoHomePage> {
  final NodeCacheService _cacheService = NodeCacheService();
  late final LocalSubServer _subServer;

  List<ProxyNode> _allNodes = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;

  String _selectedProtocol = '全部';
  String _searchQuery = '';
  bool _isPinging = false;
  bool _preferMirror = true;

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _protocolFilters = [
    '全部',
    'Hysteria2',
    'VLESS',
    'Sing-box',
    'Xray',
    'Hysteria1',
    'Juicity',
    'NaiveProxy',
    'ShadowQUIC',
  ];

  @override
  void initState() {
    super.initState();
    _subServer = LocalSubServer(getNodes: () => _allNodes);
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subServer.stop();
    super.dispose();
  }

  Future<void> _initData() async {
    // 1. Load from cache first for millisecond startup
    final (cachedNodes, cachedStats) = await _cacheService.loadCache();
    if (cachedNodes.isNotEmpty && mounted) {
      setState(() {
        _allNodes = cachedNodes;
        _stats = cachedStats;
      });
    }

    // 2. If no cache exists, fetch immediately
    if (_allNodes.isEmpty) {
      _fetchNodes();
    }
  }

  Future<void> _fetchNodes() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _statusMessage = '正在连接多源配置...';
      _progress = 0.0;
    });

    try {
      final (nodes, stats) = await NodeFetcher.fetchAllSourcesDedup(
        preferMirror: _preferMirror,
        onProgress: (p, msg) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusMessage = msg;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _allNodes = nodes;
          _stats = stats;
          _isLoading = false;
          _statusMessage = '';
        });

        // Persist to local cache
        await _cacheService.saveCache(nodes, stats: stats);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已成功提取 ${nodes.length} 个去重节点 (拦截重复 ${stats['dedup_count'] ?? 0} 个)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拉取异常: $e，已保留本地缓存节点')),
        );
      }
    }
  }

  Future<void> _pingAllNodes() async {
    if (_isPinging || _allNodes.isEmpty) return;
    setState(() => _isPinging = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在并发探测节点 TCP 延迟...'), duration: Duration(seconds: 2)),
    );

    await NodePingService.pingAllNodes(
      _allNodes,
      concurrency: 12,
      onNodePinged: (node, latency) {
        if (mounted) setState(() {});
      },
    );

    if (mounted) {
      setState(() => _isPinging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全量节点测速完成')),
      );
    }
  }

  Color _getProtocolColor(String protocol) {
    final p = protocol.toLowerCase();
    if (p.contains('hy2') || p.contains('hysteria2')) return Colors.purple;
    if (p.contains('vless')) return Colors.indigo;
    if (p.contains('singbox') || p.contains('sing-box')) return Colors.teal;
    if (p.contains('xray')) return Colors.blue;
    if (p.contains('vmess')) return Colors.cyan;
    if (p.contains('trojan')) return Colors.deepOrange;
    if (p.contains('tuic')) return Colors.green;
    if (p.contains('juicity')) return Colors.amber.shade800;
    if (p.contains('naive')) return Colors.brown;
    return Colors.blueGrey;
  }

  List<ProxyNode> _getFilteredNodes() {
    return _allNodes.where((node) {
      // Protocol filter
      if (_selectedProtocol != '全部') {
        final filter = _selectedProtocol.toLowerCase();
        final p = node.protocol.toLowerCase();
        final tag = node.sourceTag.toLowerCase();
        if (filter == 'sing-box' && !(p.contains('singbox') || tag.contains('singbox'))) return false;
        if (filter == 'hysteria2' && !(p.contains('hy2') || p.contains('hysteria2'))) return false;
        if (filter == 'hysteria1' && !(p == 'hysteria' || p == 'hy1')) return false;
        if (filter == 'vless' && !p.contains('vless')) return false;
        if (filter == 'xray' && !tag.contains('xray')) return false;
        if (filter == 'juicity' && !p.contains('juicity')) return false;
        if (filter == 'naiveproxy' && !p.contains('naive')) return false;
        if (filter == 'shadowquic' && !p.contains('shadowquic')) return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = node.name.toLowerCase().contains(q) ||
            node.server.toLowerCase().contains(q) ||
            node.sourceTag.toLowerCase().contains(q) ||
            node.protocol.toLowerCase().contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  void _showClientImportSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('一键唤醒 Android / iOS 客户端导入', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('点击直接唤起本机已安装的代理客户端，或复制配置：', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.rocket_launch, color: Colors.white)),
                title: const Text('v2rayNG'),
                subtitle: const Text('支持一键剪贴板导入或 URL Scheme 唤醒'),
                onTap: () {
                  Navigator.pop(ctx);
                  final b64 = NodeExporter.generateSubscriptionBase64(_allNodes, client: 'v2rayng');
                  Clipboard.setData(ClipboardData(text: b64));
                  NodeExporter.launchClientScheme('v2rayng://install-sub?name=ChromeGo');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制 v2rayNG 专用订阅并尝试唤起客户端')),
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.shield, color: Colors.white)),
                title: const Text('Clash Meta / Flclash'),
                subtitle: const Text('复制完整规则配置 YAML，可直接粘贴为新配置'),
                onTap: () {
                  Navigator.pop(ctx);
                  final clashYaml = NodeExporter.generateFullClashConfig(_allNodes);
                  Clipboard.setData(ClipboardData(text: clashYaml));
                  NodeExporter.launchClientScheme('clash://install-config');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制 Clash 完整规则配置 YAML')),
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.all_inclusive, color: Colors.white)),
                title: const Text('Sing-box / Nekobox'),
                subtitle: const Text('复制全部通用分享链接，支持批量一键导入'),
                onTap: () {
                  Navigator.pop(ctx);
                  final plain = NodeExporter.generatePlainShareLinks(_allNodes);
                  Clipboard.setData(ClipboardData(text: plain));
                  NodeExporter.launchClientScheme('sing-box://');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制全部通用分享链接')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCopyOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('复制节点与配置', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('复制通用分享链接 (明文换行)'),
                subtitle: Text('共 ${_allNodes.length} 个节点，包含 hy2, vless, vmess 等'),
                onTap: () {
                  Navigator.pop(ctx);
                  final text = NodeExporter.generatePlainShareLinks(_allNodes);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制 ${_allNodes.length} 条节点链接至剪贴板')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.subscriptions),
                title: const Text('复制 Base64 订阅文本 (Shadowrocket/v2rayNG)'),
                subtitle: const Text('标准 Base64 格式，客户端可直接从剪贴板导入'),
                onTap: () {
                  Navigator.pop(ctx);
                  final text = NodeExporter.generateSubscriptionBase64(_allNodes);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制 Base64 订阅文本至剪贴板')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('复制 Clash Meta 完整配置 (YAML)'),
                subtitle: const Text('内置自动测速与分流规则组'),
                onTap: () {
                  Navigator.pop(ctx);
                  final text = NodeExporter.generateFullClashConfig(_allNodes);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制 Clash Meta YAML 配置')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredNodes = _getFilteredNodes();

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('ChromeGo 节点提取器', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isPinging
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.speed),
            tooltip: '一键测速',
            onPressed: _isPinging ? null : _pingAllNodes,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置与订阅',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ChromeGoSettingsDialog(
                  preferMirror: _preferMirror,
                  onPreferMirrorChanged: (val) => setState(() => _preferMirror = val),
                  subServer: _subServer,
                  onServerToggled: () async {
                    if (_subServer.isRunning) {
                      await _subServer.stop();
                    } else {
                      await _subServer.start();
                    }
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading progress indicator
          if (_isLoading) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(_statusMessage, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],

          // Hero Stats Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('有效节点', '${_allNodes.length}', Colors.blue),
                    _buildStatItem('去重拦截', '${_stats['dedup_count'] ?? 0}', Colors.orange),
                    _buildStatItem(
                      '已连通',
                      '${_allNodes.where((n) => n.pingMs != null && n.pingMs! > 0).length}',
                      Colors.green,
                    ),
                    _buildStatItem(
                      '服务端口',
                      _subServer.isRunning ? '${_subServer.actualPort}' : '已关',
                      _subServer.isRunning ? Colors.purple : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索节点别名、IP 或协议...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _protocolFilters.map((filter) {
                final isSelected = _selectedProtocol == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedProtocol = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Node List
          Expanded(
            child: filteredNodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          _isLoading ? '正在获取节点...' : '暂无匹配的节点',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                        if (!_isLoading) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新拉取'),
                            onPressed: _fetchNodes,
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filteredNodes.length,
                    itemBuilder: (ctx, index) {
                      final node = filteredNodes[index];
                      return _buildNodeCard(node, theme);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新拉取'),
                  onPressed: _isLoading ? null : _fetchNodes,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制配置'),
                  onPressed: _allNodes.isEmpty ? null : _showCopyOptions,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.qr_code),
                tooltip: '批量二维码',
                onPressed: _allNodes.isEmpty
                    ? null
                    : () => showDialog(
                          context: context,
                          builder: (_) => BatchQrDialog(nodes: _allNodes),
                        ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                icon: const Icon(Icons.input),
                tooltip: '客户端导入',
                onPressed: _allNodes.isEmpty ? null : _showClientImportSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildNodeCard(ProxyNode node, ThemeData theme) {
    final protoColor = _getProtocolColor(node.protocol);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: protoColor.withValues(alpha: 0.15),
          child: Text(
            node.protocol.length > 3 ? node.protocol.substring(0, 3).toUpperCase() : node.protocol.toUpperCase(),
            style: TextStyle(color: protoColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          node.cleanName(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${node.server}:${node.port}',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
            if (node.sourceTag.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                node.sourceTag,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ping latency badge
            if (node.pingMs != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: node.pingMs! < 0
                      ? Colors.red.withValues(alpha: 0.12)
                      : (node.pingMs! < 400 ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  node.pingMs! < 0 ? '超时' : '${node.pingMs}ms',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: node.pingMs! < 0
                        ? Colors.red
                        : (node.pingMs! < 400 ? Colors.green : Colors.orange),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.qr_code, size: 20),
              tooltip: '查看二维码',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => SingleQrDialog(node: node),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '复制链接',
              onPressed: () {
                final link = node.toShareLink();
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已复制: ${node.cleanName()}')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
