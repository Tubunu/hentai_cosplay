import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/ygjgl_browse_provider.dart';
import '../../../services/ygjgl/ygjgl_api_service.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/liquid_glass.dart';
import 'details/ygjgl_audio_detail_page.dart';
import 'details/ygjgl_post_detail_page.dart';
import 'details/ygjgl_vod_detail_page.dart';
import 'dialogs/ygjgl_batch_download_dialog.dart';
import 'sub_pages/ygjgl_audio_sub_page.dart';
import 'sub_pages/ygjgl_image_sub_page.dart';
import 'sub_pages/ygjgl_vod_sub_page.dart';

class YgjglMainPage extends StatefulWidget {
  const YgjglMainPage({super.key});

  @override
  State<YgjglMainPage> createState() => _YgjglMainPageState();
}

class _YgjglMainPageState extends State<YgjglMainPage> {
  bool _isRandomLoading = false;

  void _triggerRandom(BuildContext context) async {
    if (_isRandomLoading) return;
    setState(() => _isRandomLoading = true);

    final nav = Navigator.of(context);
    final prov = context.read<YgjglBrowseProvider>();

    try {
      if (prov.activeSubTab == 0) {
        // VOD
        final item = await YgjglApiService.fetchRandomVodItem(
          totalCount: prov.vodTotalCount > 0 ? prov.vodTotalCount : 11000,
        );
        if (item != null && mounted) {
          nav.push(
            CupertinoPageRoute(builder: (_) => YgjglVodDetailPage(item: item)),
          );
        }
      } else if (prov.activeSubTab == 1) {
        // Image
        final randId = await YgjglApiService.fetchRandomPostId(kind: 'image');
        if (randId != null && mounted) {
          final post = await YgjglApiService.fetchPostDetail(randId, defaultKind: 'image');
          if (post != null && mounted) {
            nav.push(
              CupertinoPageRoute(builder: (_) => YgjglPostDetailPage(item: post)),
            );
          }
        }
      } else {
        // Audio
        final randId = await YgjglApiService.fetchRandomPostId(kind: 'audio');
        if (randId != null && mounted) {
          final post = await YgjglApiService.fetchPostDetail(randId, defaultKind: 'audio');
          if (post != null && mounted) {
            nav.push(
              CupertinoPageRoute(builder: (_) => YgjglAudioDetailPage(item: post)),
            );
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRandomLoading = false);
    }
  }

  void _showBatchDownload(BuildContext context) {
    final prov = context.read<YgjglBrowseProvider>();
    final curPage = prov.activeSubTab == 0
        ? prov.vodCurrentPage
        : (prov.activeSubTab == 1 ? prov.imageCurrentPage : prov.audioCurrentPage);
    final totalPages = prov.activeSubTab == 0
        ? prov.vodTotalPages
        : (prov.activeSubTab == 1 ? prov.imageTotalPages : prov.audioTotalPages);

    YgjglBatchDownloadDialog.show(
      context,
      subTab: prov.activeSubTab,
      currentPage: curPage,
      totalPages: totalPages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prov = context.watch<YgjglBrowseProvider>();
    const accentPink = Color(0xFFFF5A8A);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF7F8FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Sleek Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  // Brand Icon & Title
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5A8A), Color(0xFFFF8FB3)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accentPink.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.flame_fill, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '一个够了',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'ygjgl.one',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Random Button (🎲 随机)
                  BouncingButton(
                    onTap: () => _triggerRandom(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222226) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E2E34) : const Color(0xFFE5E5EA),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isRandomLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CupertinoActivityIndicator(radius: 6),
                                )
                              : const Text('🎲', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '随机',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Batch Download Button (📥 批量下载)
                  BouncingButton(
                    onTap: () => _showBatchDownload(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5A8A), Color(0xFFFF8FB3)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentPink.withOpacity(0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.square_stack_3d_down_right_fill, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            '批量下载',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Sub-Navigation Tabs Capsule (点播, 写真, 电台)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LiquidGlass(
                borderRadius: 16,
                blur: 16,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildSubTabItem(
                      index: 0,
                      label: '🎬 点播',
                      isSelected: prov.activeSubTab == 0,
                      onTap: () => prov.setActiveSubTab(0),
                      isDark: isDark,
                    ),
                    _buildSubTabItem(
                      index: 1,
                      label: '📸 写真',
                      isSelected: prov.activeSubTab == 1,
                      onTap: () => prov.setActiveSubTab(1),
                      isDark: isDark,
                    ),
                    _buildSubTabItem(
                      index: 2,
                      label: '📻 电台',
                      isSelected: prov.activeSubTab == 2,
                      onTap: () => prov.setActiveSubTab(2),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // 3. Sub-pages
            Expanded(
              child: IndexedStack(
                index: prov.activeSubTab,
                children: const [
                  YgjglVodSubPage(),
                  YgjglImageSubPage(),
                  YgjglAudioSubPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabItem({
    required int index,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const accentPink = Color(0xFFFF5A8A);

    return Expanded(
      child: BouncingButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C30) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? accentPink
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
