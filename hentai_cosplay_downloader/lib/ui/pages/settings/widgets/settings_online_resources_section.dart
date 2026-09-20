import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/providers/browsing_history_provider.dart';
import 'package:hentai_cosplay_downloader/ui/pages/history/browsing_history_page.dart';
import 'package:hentai_cosplay_downloader/ui/pages/settings/resource_order_setting_page.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:provider/provider.dart';
import 'settings_shared_widgets.dart';

class SettingsOnlineResourcesSection extends StatelessWidget {
  const SettingsOnlineResourcesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: '在线资源管理'),
        SettingsCard(
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
                          '在线图片与视频管理 (排序与显示)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '图片11站与视频26站独立分段排序，自由设置显示或隐藏特定网站',
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
                          Text('去管理', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
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
      ],
    );
  }
}
