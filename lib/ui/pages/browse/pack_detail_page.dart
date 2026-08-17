import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/pack_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/frosted_glass.dart';
import '../../widgets/photo_viewer_page.dart';

class PackDetailPage extends StatelessWidget {
  final PackItem item;

  const PackDetailPage({super.key, required this.item});

  void _downloadAll(BuildContext context) {
    final downloadProv = context.read<DownloadProvider>();
    final settingsProv = context.read<SettingsProvider>();
    downloadProv.updateConfig(settingsProv.config);
    downloadProv.addSinglePack(item);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 "${item.title}" 加入下载队列'),
        backgroundColor: IosTheme.primaryPink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsProv = context.watch<SettingsProvider>();

    // Resolve candidate full URLs for previewing
    final List<String> previewUrls = item.urls.map((u) {
      if (u.startsWith('/')) {
        final domain = settingsProv.config.proxyDomains.isNotEmpty
            ? settingsProv.config.proxyDomains.first.replaceAll(RegExp(r'/+$'), '')
            : 'https://tgproxy.1258012.xyz';
        return '$domain$u';
      }
      return u;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF7F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Album Header with Ambient Blur
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xE61A1A1E) : const Color(0xF0FFFFFF),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 15,
                backgroundColor: isDark ? Colors.black45 : Colors.white60,
                child: IconButton(
                  icon: const Icon(CupertinoIcons.chevron_back, size: 20),
                  color: isDark ? Colors.white : Colors.black,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FrostedGlass(
                  borderRadius: 20,
                  blur: 15,
                  backgroundColor: isDark ? Colors.black45 : Colors.white60,
                  child: IconButton(
                    icon: const Icon(CupertinoIcons.arrow_down_to_line, color: IosTheme.primaryPink, size: 20),
                    onPressed: () => _downloadAll(context),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient blurred background
                  if (item.coverUrl != null)
                    CachedNetworkImage(
                      imageUrl: item.coverUrl!,
                      fit: BoxFit.cover,
                    ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: isDark
                          ? Colors.black.withOpacity(0.65)
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),

                  // Center Album Artwork
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: item.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: item.coverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(child: CupertinoActivityIndicator()),
                                  errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 40),
                                )
                              : const Icon(CupertinoIcons.photo),
                        ),
                      ),
                    ),
                  ),

                  // Album metadata title & author
                  Positioned(
                    bottom: 12,
                    left: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.author}  •  共 ${item.urls.length} 张图片',
                          style: TextStyle(
                            fontSize: 13,
                            color: IosTheme.secondaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Download Action Pill Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: BouncingButton(
                      onTap: () => _downloadAll(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: IosTheme.musicGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: IosTheme.primaryPink.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.arrow_down_circle_fill, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '下载整包图集',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Images Grid Section
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final url = previewUrls[index];
                  return BouncingButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => PhotoViewerPage(
                            images: previewUrls,
                            initialIndex: index,
                            title: item.title,
                            isLocalFile: false,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0),
                                child: const Center(child: CupertinoActivityIndicator(radius: 10)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: isDark ? const Color(0xFF222226) : const Color(0xFFEBEBF0),
                                child: const Center(child: Icon(CupertinoIcons.photo, size: 24)),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: previewUrls.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
