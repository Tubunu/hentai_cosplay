import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ios_theme.dart';
import 'bouncing_button.dart';
import 'chrome_insets_coordinator.dart';
import 'liquid_glass.dart';
import 'page_navigation_bar.dart';
import 'scroll_to_top_button.dart';
import 'unified_media_card.dart';
import 'unified_media_card_skeleton.dart';

/// Unified browse scaffold for all 34 image and video sites.
/// Encapsulates auto-hiding chrome, responsive grid, pull-to-refresh,
/// pagination, and batch operation toolbar.
class UnifiedMediaBrowseScaffold<T> extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final bool isLoading;
  final String? errorMessage;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final UnifiedMediaType mediaType;
  final Color brandColor;

  // Header & Controls
  final Widget? header;
  final List<Widget>? headerSlivers;

  // Pagination
  final int currentPage;
  final int totalPages;
  final ValueChanged<int>? onPageSelected;

  // Batch Selection
  final bool isSelectionMode;
  final int selectedCount;
  final VoidCallback? onToggleSelectAll;
  final bool isAllSelected;
  final VoidCallback? onDownloadSelected;
  final VoidCallback? onExitSelectionMode;

  const UnifiedMediaBrowseScaffold({
    super.key,
    required this.scrollController,
    required this.onRefresh,
    required this.items,
    required this.itemBuilder,
    this.isLoading = false,
    this.errorMessage,
    this.mediaType = UnifiedMediaType.video,
    this.brandColor = IosTheme.primaryPink,
    this.header,
    this.headerSlivers,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPageSelected,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.onToggleSelectAll,
    this.isAllSelected = false,
    this.onDownloadSelected,
    this.onExitSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topOffset = ChromeInsets.top(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Scroll content with auto-hiding coordination
          ChromeScrollWrapper(
            controller: scrollController,
            child: RefreshIndicator(
              color: brandColor,
              edgeOffset: topOffset,
              displacement: 36.0,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await onRefresh();
              },
              child: CustomScrollView(
                controller: scrollController,
                cacheExtent: 600.0,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. Top safe spacing for floating site selector pill bar
                  SliverToBoxAdapter(
                    child: SizedBox(height: topOffset),
                  ),

                  // 2. Custom header (e.g. search, site tabs, category filters)
                  if (header != null)
                    SliverToBoxAdapter(child: header!),

                  // Additional header slivers if any
                  if (headerSlivers != null) ...headerSlivers!,

                  // 3. Main Content: Loading, Error, Empty, or Grid
                  if (isLoading && items.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final isVideo = mediaType == UnifiedMediaType.video;
                          final crossAxisCount = isVideo
                              ? (width < 500 ? 2 : (width < 800 ? 3 : (width < 1200 ? 4 : 5)))
                              : (width < 500 ? 2 : (width < 800 ? 3 : (width < 1200 ? 4 : 6)));
                          final childAspectRatio = IosTheme.cardAspectRatio(isVideo: isVideo);

                          return SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: childAspectRatio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, idx) => UnifiedMediaCardSkeleton(mediaType: mediaType),
                              childCount: crossAxisCount * 3,
                            ),
                          );
                        },
                      ),
                    )
                  else if (errorMessage != null && items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                size: 44,
                                color: brandColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => onRefresh(),
                                icon: const Icon(CupertinoIcons.refresh, size: 14),
                                label: const Text('重试'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brandColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.tray,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '暂无相关内容',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Responsive Grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final isVideo = mediaType == UnifiedMediaType.video;

                          // Dynamic columns based on screen width
                          int crossAxisCount;
                          double childAspectRatio;

                          if (isVideo) {
                            if (width < 500) {
                              crossAxisCount = 2;
                            } else if (width < 800) {
                              crossAxisCount = 3;
                            } else if (width < 1200) {
                              crossAxisCount = 4;
                            } else {
                              crossAxisCount = 5;
                            }
                          } else {
                            if (width < 500) {
                              crossAxisCount = 2;
                            } else if (width < 800) {
                              crossAxisCount = 3;
                            } else if (width < 1200) {
                              crossAxisCount = 4;
                            } else {
                              crossAxisCount = 6;
                            }
                          }
                          childAspectRatio = IosTheme.cardAspectRatio(isVideo: isVideo);

                          return SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: childAspectRatio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, idx) => itemBuilder(ctx, items[idx], idx),
                              childCount: items.length,
                              addAutomaticKeepAlives: true,
                              addRepaintBoundaries: true,
                            ),
                          );
                        },
                      ),
                    ),

                  // 4. Standard Bottom Pagination Bar
                  if (totalPages > 1 && onPageSelected != null && items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: PageNavigationBar(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        isLoading: isLoading,
                        brandColor: brandColor,
                        onPageSelected: (p) {
                          onPageSelected!(p);
                          if (scrollController.hasClients) {
                            scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                      ),
                    ),

                  // 5. Dynamic bottom spacer to prevent obstruction by bottom navigation & mini player
                  const ChromeSliverBottomSpacing(extra: 24.0),
                ],
              ),
            ),
          ),

          // Scroll to top button (floating above right)
          ScrollToTopButton(
            scrollController: scrollController,
            color: brandColor,
            rightOffset: 14,
            bottomOffset: ChromeInsets.floatingBottom(context, extra: 16),
          ),

          // 6. Floating Batch Selection Action Bar
          if (isSelectionMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: ChromeInsets.floatingBottom(context, extra: 12),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                offset: isSelectionMode ? Offset.zero : const Offset(0, 1.5),
                child: AppGlassSurface(
                  tier: GlassTier.modal,
                  borderRadius: 22,
                  auraColor: brandColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: brandColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '已选 $selectedCount 项',
                          style: TextStyle(
                            color: brandColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (onToggleSelectAll != null)
                        TextButton(
                          onPressed: onToggleSelectAll,
                          child: Text(
                            isAllSelected ? '取消全选' : '全选本页',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (onDownloadSelected != null)
                        BouncingButton(
                          onTap: selectedCount > 0 ? onDownloadSelected : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selectedCount > 0 ? brandColor : Colors.grey.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: selectedCount > 0
                                  ? [
                                      BoxShadow(
                                        color: brandColor.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '下载选中',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      if (onExitSelectionMode != null)
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
                          color: isDark ? Colors.white54 : Colors.black45,
                          onPressed: onExitSelectionMode,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
