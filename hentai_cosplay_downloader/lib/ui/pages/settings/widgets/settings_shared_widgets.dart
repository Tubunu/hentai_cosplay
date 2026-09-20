import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/ui/theme/ios_theme.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final Widget child;

  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IosTheme.surfaceLayer1(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: IosTheme.borderSubtle(isDark),
          width: 0.6,
        ),
      ),
      child: child,
    );
  }
}
