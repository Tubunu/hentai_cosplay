import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/disguise_provider.dart';
import '../../providers/settings_provider.dart';
import '../pages/disguise/someacg_disguise_page.dart';
import '../pages/home_scaffold.dart';

class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key});

  @override
  Widget build(BuildContext context) {
    final disguiseMode = context.select<SettingsProvider, bool>(
      (p) => p.config.disguiseMode,
    );

    // 默认关闭伪装，直接进入应用，零额外开销
    if (!disguiseMode) {
      return const HomeScaffold();
    }

    final isUnlocked = context.select<DisguiseProvider, bool>(
      (p) => p.isUnlocked,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: isUnlocked
          ? const HomeScaffold(key: ValueKey('real_home_scaffold'))
          : const SomeAcgDisguisePage(key: ValueKey('someacg_disguise_page')),
    );
  }
}
