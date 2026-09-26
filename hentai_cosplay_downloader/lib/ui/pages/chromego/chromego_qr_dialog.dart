import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/chromego/proxy_node.dart';
import '../../../services/chromego/chromego_exporter.dart';

/// Dialog for displaying a single node QR code.
class SingleQrDialog extends StatelessWidget {
  final ProxyNode node;

  const SingleQrDialog({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final link = node.toShareLink();
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    node.cleanName(),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // White Quiet Zone container to guarantee scannability in dark mode
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 240,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${node.protocol.toUpperCase()} • ${node.server}:${node.port}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制链接'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已复制 ${node.protocol.toUpperCase()} 链接')),
                    );
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('完成'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for displaying batch QR code (一码全入 / 分批展示).
class BatchQrDialog extends StatefulWidget {
  final List<ProxyNode> nodes;

  const BatchQrDialog({super.key, required this.nodes});

  @override
  State<BatchQrDialog> createState() => _BatchQrDialogState();
}

class _BatchQrDialogState extends State<BatchQrDialog> {
  String _targetClient = 'shadowrocket'; // shadowrocket, v2rayng
  bool _compactRemark = true;
  bool _usePaging = false;
  int _currentPage = 0;
  static const int _pageSize = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligibleNodes = widget.nodes.where((n) => n.isSupportedBy(_targetClient)).toList();

    List<ProxyNode> displayNodes;
    int totalPages = 1;
    if (_usePaging && eligibleNodes.length > _pageSize) {
      totalPages = (eligibleNodes.length / _pageSize).ceil();
      _currentPage = _currentPage.clamp(0, totalPages - 1);
      final start = _currentPage * _pageSize;
      final end = (start + _pageSize).clamp(0, eligibleNodes.length);
      displayNodes = eligibleNodes.sublist(start, end);
    } else {
      displayNodes = eligibleNodes;
    }

    final payload = NodeExporter.generateBatchQrPayload(
      displayNodes,
      _targetClient,
      compact: _compactRemark,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '批量扫码导入 (一码全入)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Target client selector segment
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'shadowrocket', label: Text('小火箭/通用')),
                  ButtonSegment(value: 'v2rayng', label: Text('v2rayNG')),
                ],
                selected: {_targetClient},
                onSelectionChanged: (set) {
                  setState(() {
                    _targetClient = set.first;
                    _currentPage = 0;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Options: compact remark & paging
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('极简别名降密'),
                    selected: _compactRemark,
                    onSelected: (v) => setState(() => _compactRemark = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(eligibleNodes.length > 5 ? '分批模式 (5个/页)' : '全部合并'),
                    selected: _usePaging,
                    onSelected: eligibleNodes.length > 5 ? (v) => setState(() => _usePaging = v) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // QR display with White Quiet Zone
              if (payload.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 240,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                )
              else
                Container(
                  height: 240,
                  alignment: Alignment.center,
                  child: const Text('当前客户端暂无支持的节点'),
                ),

              if (_usePaging && totalPages > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                    ),
                    Text('第 ${_currentPage + 1} / $totalPages 批 (${displayNodes.length}个)'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  '已包含 ${displayNodes.length} 个可用节点',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ],

              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制订阅 Base64'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: payload));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已复制 ${displayNodes.length} 个节点的 Base64 订阅文本')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
