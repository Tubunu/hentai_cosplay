import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/video_item.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/video_browse_provider.dart';
import '../../../services/video_api_service.dart';
import '../../theme/ios_theme.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/frosted_glass.dart';

class VideoDetailPage extends StatefulWidget {
  final VideoItem initialItem;

  const VideoDetailPage({super.key, required this.initialItem});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late VideoItem _item;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    _loadVideoDetails();
  }

  Future<void> _loadVideoDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detailed = await VideoApiService.fetchVideoDetail(_item);
      if (detailed != null) {
        setState(() {
          _item = detailed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '解析视频详情失败，请检查网络';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载出错: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloadProv = context.watch<DownloadProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF2F2F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible App Bar with 16:9 Video Poster
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            leading: BouncingButton(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
              ),
            ),
            actions: [
              BouncingButton(
                onTap: () {
                  Share.share('${_item.title}\n${_item.detailUrl}');
                },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.share, color: Colors.white, size: 18),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _item.coverUrl != null && _item.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _item.coverUrl!,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Referer': 'https://porn-video-xxx.com/',
                          },
                        )
                      : Container(color: Colors.grey[900]),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              _item.author,
                              style: const TextStyle(
                                color: IosTheme.primaryPink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_item.duration.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _item.duration,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Button Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: BouncingButton(
                      onTap: () {
                        downloadProv.addVideoTask(_item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已加入视频下载队列: ${_item.title}'),
                            backgroundColor: IosTheme.primaryPink,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: IosTheme.primaryPink,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: IosTheme.primaryPink.withValues(alpha: 0.35),
                              blurRadius: 12,
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
                              '一键下载视频',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
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

          // Video Tags Row (if loaded)
          if (_item.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _item.tags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: BouncingButton(
                          onTap: () {
                            context.read<VideoBrowseProvider>().setTag(tag);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.tag_fill, size: 11, color: IosTheme.primaryPink),
                                const SizedBox(width: 5),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

          // Video Detail Information Container
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: FrostedGlass(
                borderRadius: 20,
                blur: 15,
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? const Color(0x9924242A) : const Color(0xDDFFFFFF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '视频详细信息',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CupertinoActivityIndicator(radius: 8),
                            SizedBox(width: 8),
                            Text('正在解析视频播放源与完整信息...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    else if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                      ),
                    _buildInfoRow('作者 / 演者', _item.author, isDark),
                    if (_item.duration.isNotEmpty) _buildInfoRow('视频时长', _item.duration, isDark),
                    if (_item.date.isNotEmpty) _buildInfoRow('发布时间', _item.date, isDark),
                    _buildInfoRow('原始页面', _item.detailUrl, isDark),
                    if (_item.videoUrl != null)
                      _buildInfoRow('视频流解析', '已成功解析Direct MP4源', isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
