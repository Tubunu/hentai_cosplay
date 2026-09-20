enum ResourceMediaType {
  image,
  video;

  String get label => switch (this) {
        ResourceMediaType.image => '在线图片',
        ResourceMediaType.video => '在线视频',
      };
}

enum ResourceCategory {
  gallery,
  jav,
  anime,
  video,
  creator;

  String get label => switch (this) {
        ResourceCategory.gallery => '写真图集',
        ResourceCategory.jav => '日本 JAV',
        ResourceCategory.anime => '动漫 3D',
        ResourceCategory.video => '综合影视',
        ResourceCategory.creator => '创作者/社媒',
      };
}
