import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:provider/provider.dart';
import 'settings_shared_widgets.dart';

class SettingsConcurrencySection extends StatelessWidget {
  const SettingsConcurrencySection({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProv = context.watch<SettingsProvider>();
    final config = settingsProv.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Concurrency & Performance
        const SettingsSectionHeader(title: '多线程并发'),
        SettingsCard(
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

        // Section: Jable Settings
        const SettingsSectionHeader(title: 'Jable 影视设置'),
        SettingsCard(
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
      ],
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
