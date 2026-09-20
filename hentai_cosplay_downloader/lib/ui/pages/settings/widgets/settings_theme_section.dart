import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:provider/provider.dart';
import 'settings_shared_widgets.dart';

class SettingsThemeSection extends StatelessWidget {
  const SettingsThemeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final config = settingsProv.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: '主题与外观'),
        SettingsCard(
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, thickness: 0.5),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '滚动时自动收起顶底栏',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '向上滑动浏览媒体时自动收起导航栏，向下滑动复位，释放全屏沉浸视口',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoSwitch(
                    activeTrackColor: IosTheme.primaryPink,
                    value: config.autoHideNavigationOnScroll,
                    onChanged: (val) {
                      settingsProv.setAutoHideNavigationOnScroll(val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
}
