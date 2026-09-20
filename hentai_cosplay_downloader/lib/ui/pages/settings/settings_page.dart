import 'package:flutter/material.dart';
import '../../widgets/chrome_insets_coordinator.dart';
import 'widgets/settings_concurrency_section.dart';
import 'widgets/settings_disguise_section.dart';
import 'widgets/settings_network_section.dart';
import 'widgets/settings_online_resources_section.dart';
import 'widgets/settings_storage_section.dart';
import 'widgets/settings_theme_section.dart';
import 'widgets/settings_viewer_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, ChromeInsets.bottom(context, extra: 24)),
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

            // 1. Storage & Paths
            const SettingsStorageSection(),
            const SizedBox(height: 18),

            // 2. Concurrency & Performance
            const SettingsConcurrencySection(),
            const SizedBox(height: 18),

            // 3. Network & Proxy
            const SettingsNetworkSection(),
            const SizedBox(height: 18),

            // 4. Online Resources
            const SettingsOnlineResourcesSection(),
            const SizedBox(height: 18),

            // 5. Disguise & Privacy
            const SettingsDisguiseSection(),
            const SizedBox(height: 18),

            // 6. Theme & Appearance
            const SettingsThemeSection(),
            const SizedBox(height: 18),

            // 7. Viewer & Browsing
            const SettingsViewerSection(),
            const SizedBox(height: 20),

            // 8. App Info Footer
            Center(
              child: Column(
                children: [
                  const Text(
                    'Hentai Cosplay Downloader v1.0.9',
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
}
