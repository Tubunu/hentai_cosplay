import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/disguise_provider.dart';
import '../../providers/settings_provider.dart';
import '../pages/disguise/someacg_disguise_page.dart';

/// 全局应用锁门禁（AppLockGate）
///
/// 采用独立覆盖层设计（Overlay-over-Navigator）：
/// - 真实业务内容（widget.child）常驻在底层 Navigator 中，其路由栈、滚动进度与看图状态永不销毁。
/// - 当触发伪装锁定（切到后台 / 手动锁定）时，顶层的伪装门户（SomeACG）立即全屏覆盖。
/// - 伪装层拥有独立的内部 Navigator，点击壁纸详情、分类浏览均在伪装层内部跳转，绝不干扰底层真应用。
/// - 解锁后，伪装层丝滑淡出，用户立即无缝回到原图集/视频详情页继续浏览，彻底杜绝进度丢失。
class AppLockGate extends StatelessWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final disguiseMode = context.select<SettingsProvider, bool>(
      (p) => p.config.disguiseMode,
    );

    // 未开启伪装模式时，零额外消耗，直接返回业务视图
    if (!disguiseMode) {
      return child;
    }

    return _DisguiseOverlayGate(child: child);
  }
}

class _DisguiseOverlayGate extends StatefulWidget {
  final Widget child;

  const _DisguiseOverlayGate({required this.child});

  @override
  State<_DisguiseOverlayGate> createState() => _DisguiseOverlayGateState();
}

class _DisguiseOverlayGateState extends State<_DisguiseOverlayGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  DisguiseProvider? _disguiseProvider;
  bool _isOverlayMounted = true;

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted && (_disguiseProvider?.isUnlocked ?? true)) {
          setState(() {
            _isOverlayMounted = false;
          });
        }
      }
    });
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isAuthenticating) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (!mounted) return;
    final biometricUnlock = context.read<SettingsProvider>().config.disguiseBiometricUnlock;
    if (!biometricUnlock) return;
    _isAuthenticating = true;

    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) return;

      final authenticated = await _localAuth.authenticate(
        localizedReason: '请验证指纹或面容以解锁',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );

      if (authenticated && mounted) {
        _disguiseProvider?.unlock();
      }
    } catch (e) {
      debugPrint('[AppLockGate] Biometric auth silent error: $e');
    } finally {
      if (mounted) {
        _isAuthenticating = false;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<DisguiseProvider>();
    if (_disguiseProvider != prov) {
      _disguiseProvider?.removeListener(_onDisguiseChanged);
      _disguiseProvider = prov;
      _disguiseProvider?.addListener(_onDisguiseChanged);

      final isUnlocked = prov.isUnlocked;
      _animController.value = isUnlocked ? 0.0 : 1.0;
      _isOverlayMounted = !isUnlocked;

      if (!isUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerBiometricAuth();
        });
      }
    }
  }

  void _onDisguiseChanged() {
    if (!mounted) return;
    final isUnlocked = _disguiseProvider?.isUnlocked ?? true;
    if (isUnlocked) {
      _animController.reverse();
    } else {
      setState(() {
        _isOverlayMounted = true;
      });
      _animController.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometricAuth();
      });
    }
  }

  @override
  void dispose() {
    _disguiseProvider?.removeListener(_onDisguiseChanged);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = context.select<DisguiseProvider, bool>(
      (p) => p.isUnlocked,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 真实业务层：状态常驻，锁定时忽略指针以防误触穿透，解锁后零干涉完全交互
        IgnorePointer(
          ignoring: !isUnlocked,
          child: widget.child,
        ),

        // 2. 伪装门户层：锁定或淡出过程中覆盖在顶层，解锁动画完成即从树中彻底卸载
        if (_isOverlayMounted || !isUnlocked)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: isUnlocked, // 一旦解锁，淡出期间立即不阻挡用户点击真实应用
              child: FadeTransition(
                opacity: _animController,
                child: const SomeAcgDisguisePage(
                  key: ValueKey('someacg_disguise_page'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
