import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hentai_cosplay_downloader/providers/disguise_provider.dart';
import 'package:hentai_cosplay_downloader/providers/settings_provider.dart';
import 'package:hentai_cosplay_downloader/ui/widgets/bouncing_button.dart';
import 'package:provider/provider.dart';
import 'settings_shared_widgets.dart';

class SettingsDisguiseSection extends StatelessWidget {
  const SettingsDisguiseSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();
    final config = settingsProv.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: '应用伪装与隐私保护'),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Disguise Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2D55), Color(0xFF5856D6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'S',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '开启 SomeACG 壁纸伪装',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '未解锁时伪装成二次元壁纸站，隐藏真实内容',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  CupertinoSwitch(
                    activeTrackColor: const Color(0xFFFF2D55),
                    value: config.disguiseMode,
                    onChanged: (val) {
                      settingsProv.setDisguiseMode(val);
                      context.read<DisguiseProvider>().onDisguiseModeChanged(val);
                    },
                  ),
                ],
              ),

              if (config.disguiseMode) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 0.5),
                ),

                // Unlock Passcode setting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '搜索栏解锁暗号',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '在壁纸站搜索框输入此暗号点击搜索即可解锁',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    BouncingButton(
                      onTap: () => _showEditUnlockCodeDialog(context, config.disguiseUnlockCode, settingsProv),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              config.disguiseUnlockCode.isNotEmpty ? config.disguiseUnlockCode : 'open',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF2D55),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(CupertinoIcons.pencil, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Gesture Unlock Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '长按 Logo 快捷解锁 (3秒)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '在壁纸站长按左上角 SomeACG 标志直接进入',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      activeTrackColor: const Color(0xFFFF2D55),
                      value: config.disguiseQuickUnlock,
                      onChanged: (val) {
                        settingsProv.setDisguiseQuickUnlock(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Relock on background switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '切到后台自动锁上',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '应用退入后台后重新切回时再次进入伪装',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      activeTrackColor: const Color(0xFFFF2D55),
                      value: config.disguiseRelockOnBackground,
                      onChanged: (val) {
                        settingsProv.setDisguiseRelockOnBackground(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Biometric unlock switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '生物识别快速解锁 (面容 / 指纹)',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '在伪装页启动或切回时主动发起系统指纹/面容验证',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    CupertinoSwitch(
                      activeTrackColor: const Color(0xFFFF2D55),
                      value: config.disguiseBiometricUnlock,
                      onChanged: (val) {
                        settingsProv.setDisguiseBiometricUnlock(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Immediate Lock / Preview Button
                BouncingButton(
                  onTap: () {
                    context.read<DisguiseProvider>().lock();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFF5856D6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.lock_shield_fill, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '立即进入伪装状态 (测试或应急锁定)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showEditUnlockCodeDialog(BuildContext context, String currentCode, SettingsProvider settingsProv) {
    final controller = TextEditingController(text: currentCode);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('修改搜索栏解锁暗号'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '在伪装壁纸页的搜索框输入此暗号并点击搜索，即可解除伪装。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                placeholder: '例如: open 或 6666',
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('保存'),
            onPressed: () {
              final newCode = controller.text.trim();
              if (newCode.isNotEmpty) {
                settingsProv.setDisguiseUnlockCode(newCode);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
