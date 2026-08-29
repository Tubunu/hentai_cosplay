import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/resource_site_item.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';

class ResourceOrderSettingPage extends StatefulWidget {
  const ResourceOrderSettingPage({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const ResourceOrderSettingPage(),
      ),
    );
  }

  @override
  State<ResourceOrderSettingPage> createState() => _ResourceOrderSettingPageState();
}

class _ResourceOrderSettingPageState extends State<ResourceOrderSettingPage> {
  late List<String> _currentOrderKeys;

  @override
  void initState() {
    super.initState();
    final settingsProv = context.read<SettingsProvider>();
    _currentOrderKeys = List.from(
      ResourceSiteRegistry.getOrderedSites(settingsProv.config.onlineResourceSortOrder)
          .map((s) => s.key),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _currentOrderKeys.removeAt(oldIndex);
      _currentOrderKeys.insert(newIndex, item);
    });

    HapticFeedback.mediumImpact();
    context.read<SettingsProvider>().updateOnlineResourceSortOrder(_currentOrderKeys);
  }

  void _showResetDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('恢复默认排序'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('确定要将【在线资源】所有站点的排列顺序重置为官方默认顺序吗？'),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _currentOrderKeys = List.from(ResourceSiteRegistry.defaultOrder);
              });
              context.read<SettingsProvider>().resetOnlineResourceSortOrder();
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认站点排序'),
                  backgroundColor: IosTheme.primaryPink,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(milliseconds: 1500),
                ),
              );
            },
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderedSites = _currentOrderKeys
        .map((k) => ResourceSiteRegistry.allSites[k])
        .whereType<ResourceSiteItem>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '在线资源排序',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showResetDialog,
            icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 16),
            label: const Text('恢复默认', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header description banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 20,
                  color: IosTheme.primaryPink.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '长按右侧把手即可上下拖拽调整顺序。排在前面的站点将优先展示在【在线资源】顶部最左侧。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Reorderable list of sites
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: orderedSites.length,
              // ignore: deprecated_member_use
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final site = orderedSites[index];
                final rank = index + 1;

                return Container(
                  key: ValueKey(site.key),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                      width: 0.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rank badge
                        Container(
                          width: 22,
                          alignment: Alignment.center,
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: rank <= 3
                                  ? IosTheme.primaryPink
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Site Icon Badge
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: site.color.withValues(alpha: isDark ? 0.22 : 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: site.color.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(site.icon, color: site.color, size: 19),
                        ),
                      ],
                    ),
                    title: Text(
                      site.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      site.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          CupertinoIcons.bars,
                          color: isDark ? Colors.white38 : Colors.black38,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
