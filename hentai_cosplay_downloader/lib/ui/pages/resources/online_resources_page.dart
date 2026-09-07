import 'package:flutter/material.dart';
import '../../../models/resource_site_item.dart';
import 'online_media_page.dart';

/// 【在线图片】专区：聚焦写真图集、Cosplay与画廊站点
class OnlineImagesPage extends StatelessWidget {
  const OnlineImagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnlineMediaPage(mediaType: ResourceMediaType.image);
  }
}

/// 【在线视频】专区：聚焦日本 JAV、3D 动漫、欧美综合与创作者视频
class OnlineVideosPage extends StatelessWidget {
  const OnlineVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnlineMediaPage(mediaType: ResourceMediaType.video);
  }
}

/// 向后兼容接口，默认呈现【在线图片】
class OnlineResourcesPage extends StatelessWidget {
  const OnlineResourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnlineImagesPage();
  }
}
