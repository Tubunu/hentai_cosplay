import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
class DisguiseProvider extends ChangeNotifier {
  bool _isUnlocked;

  DisguiseProvider({required bool disguiseMode}) : _isUnlocked = !disguiseMode;

  bool get isUnlocked => _isUnlocked;

  /// 解除伪装，进入真应用
  void unlock() {
    if (_isUnlocked) return;
    _isUnlocked = true;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    notifyListeners();
  }

  /// 重新进入伪装锁定状态
  void lock() {
    if (!_isUnlocked) return;
    _isUnlocked = false;
    notifyListeners();
  }

  /// 比对暗号并尝试解锁
  bool tryUnlockWithCode(String input, String expectedCode) {
    final cleanInput = input.trim().toLowerCase();
    final cleanExpected = expectedCode.trim().toLowerCase();
    if (cleanInput.isNotEmpty && cleanInput == cleanExpected) {
      unlock();
      return true;
    }
    return false;
  }

  /// 监听生命周期（切后台自动重锁）
  void onLifecycleStateChanged(AppLifecycleState state, bool disguiseMode, bool relockOnBackground) {
    if (!disguiseMode || !relockOnBackground) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock();
    }
  }

  /// 当设置中的伪装模式开关被修改时联动
  void onDisguiseModeChanged(bool newDisguiseMode) {
    if (newDisguiseMode && _isUnlocked) {
      // 伪装模式被开启，立即锁定
      lock();
    } else if (!newDisguiseMode && !_isUnlocked) {
      // 伪装模式被关闭，立即解锁
      unlock();
    }
  }
}
