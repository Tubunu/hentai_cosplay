import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/jable_download_provider.dart';
import '../../providers/settings_provider.dart';

/// Global controller managing Chrome (Top bar & Bottom navigation) insets & auto-hide states
class ChromeInsetsController extends ChangeNotifier {
  bool _isNavHidden = false;
  double _customTopHeight = 58.0;

  bool get isNavHidden => _isNavHidden;
  double get customTopHeight => _customTopHeight;

  void setNavHidden(bool hidden) {
    if (_isNavHidden != hidden) {
      _isNavHidden = hidden;
      notifyListeners();
    }
  }

  void setCustomTopHeight(double height) {
    if (_customTopHeight != height) {
      _customTopHeight = height;
      notifyListeners();
    }
  }

  void onScrollDirection(ScrollDirection direction, {double offset = 0}) {
    if (offset <= 12) {
      if (_isNavHidden) setNavHidden(false);
      return;
    }

    if (direction == ScrollDirection.reverse && !_isNavHidden) {
      // User is scrolling down: hide chrome to reveal more content
      setNavHidden(true);
    } else if (direction == ScrollDirection.forward && _isNavHidden) {
      // User is scrolling up: reveal chrome
      setNavHidden(false);
    }
  }
}

/// Inherited scope providing ChromeInsetsController down the widget tree
class ChromeInsetsScope extends InheritedNotifier<ChromeInsetsController> {
  const ChromeInsetsScope({
    super.key,
    required ChromeInsetsController controller,
    required super.child,
  }) : super(notifier: controller);

  static ChromeInsetsController of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<ChromeInsetsScope>();
      return scope?.notifier ?? ChromeInsetsController();
    } else {
      final scope = context.getInheritedWidgetOfExactType<ChromeInsetsScope>();
      return scope?.notifier ?? ChromeInsetsController();
    }
  }
}

/// Easy-to-use static helper for calculating insets and building adaptive spacing
class ChromeInsets {
  /// 计算页面末尾所需的自适应避让高度 (针对滚动列表底部的避让留白)
  /// - 当开启【自动收起底栏】时：滑动时底栏已折叠隐藏，无需保留 72pt 胶囊底栏与浮动下载栏的冗余避让空间，
  ///   直接返回轻量安全留白 (bottomSafe + extra)，彻底杜绝滑到底部时的突兀空白。
  /// - 当关闭【自动收起底栏】时：底栏常驻固定，必须严格避让 (72 + miniBarHeight + bottomSafe + extra)，
  ///   防止翻页器或最后一张卡片被底栏遮挡。
  static double bottom(BuildContext context, {double extra = 16.0}) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final autoHideEnabled = context.select<SettingsProvider, bool>(
      (p) => p.config.autoHideNavigationOnScroll,
    );

    if (autoHideEnabled) {
      return bottomSafe + extra;
    }

    final hasCosplay = context.select<DownloadProvider, bool>(
      (p) => p.isDownloading || p.activeTasks.isNotEmpty,
    );
    final hasJable = context.select<JableDownloadProvider, bool>(
      (p) => p.isDownloading || p.activeTasks.isNotEmpty,
    );
    final hasMiniBar = hasCosplay || hasJable;

    // Bottom Nav capsule: ~72pt, MiniDownloadBar: ~64pt
    final baseBottom = 72.0 + bottomSafe;
    final miniBarHeight = hasMiniBar ? 64.0 : 0.0;

    return baseBottom + miniBarHeight + extra;
  }

  /// 计算底部浮动控件 (如悬浮回到顶部、浮动操作条等) 的动态离底间距
  /// 会根据底栏当前的展开/收起状态实时变换位置
  static double floatingBottom(BuildContext context, {double extra = 12.0}) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final isHidden = ChromeInsets.isHidden(context);

    if (isHidden) {
      return bottomSafe + extra;
    }

    final hasCosplay = context.select<DownloadProvider, bool>(
      (p) => p.isDownloading || p.activeTasks.isNotEmpty,
    );
    final hasJable = context.select<JableDownloadProvider, bool>(
      (p) => p.isDownloading || p.activeTasks.isNotEmpty,
    );
    final hasMiniBar = hasCosplay || hasJable;

    final baseBottom = 72.0 + bottomSafe;
    final miniBarHeight = hasMiniBar ? 64.0 : 0.0;

    return baseBottom + miniBarHeight + extra;
  }

  /// Computes real-time top chrome clearance
  static double top(BuildContext context, {double extra = 8.0}) {
    final topSafe = MediaQuery.of(context).padding.top;
    // Floating capsule pill bar height (~44pt) + top offset (6pt)
    return topSafe + 50.0 + extra;
  }

  /// Whether chrome is currently folded/hidden by user scroll
  static bool isHidden(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChromeInsetsScope>();
    final autoHideEnabled = context.select<SettingsProvider, bool>(
      (p) => p.config.autoHideNavigationOnScroll,
    );
    return autoHideEnabled && (scope?.notifier?.isNavHidden ?? false);
  }
}

/// Adaptive bottom spacer widget for standard Box layouts
class ChromeBottomSpacing extends StatelessWidget {
  final double extra;

  const ChromeBottomSpacing({super.key, this.extra = 16.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: ChromeInsets.bottom(context, extra: extra));
  }
}

/// Adaptive bottom spacer for Slivers (CustomScrollView)
class ChromeSliverBottomSpacing extends StatelessWidget {
  final double extra;

  const ChromeSliverBottomSpacing({super.key, this.extra = 16.0});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: ChromeInsets.bottom(context, extra: extra)),
    );
  }
}

/// Scroll listener wrapper that automatically connects any CustomScrollView to ChromeInsets
class ChromeScrollWrapper extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;

  const ChromeScrollWrapper({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final autoHideEnabled = context.select<SettingsProvider, bool>(
      (p) => p.config.autoHideNavigationOnScroll,
    );

    if (!autoHideEnabled) {
      return child;
    }

    final insetsCtrl = ChromeInsetsScope.of(context);

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          insetsCtrl.onScrollDirection(
            notification.direction,
            offset: notification.metrics.pixels,
          );
        }
        return false;
      },
      child: child,
    );
  }
}
