class WallpaperItem {
  final String id;
  final String title;
  final String previewUrl;
  final String rawUrl;
  final int width;
  final int height;
  final List<String> tags;
  final String author;
  final String resolution;
  final int likes;

  const WallpaperItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.rawUrl,
    this.width = 1920,
    this.height = 1080,
    this.tags = const [],
    this.author = 'SomeACG 精选',
    this.resolution = '4K 超清',
    this.likes = 128,
  });

  double get aspectRatio {
    if (width > 0 && height > 0) {
      final ratio = width / height;
      return ratio.clamp(0.5, 2.0);
    }
    return 0.7;
  }
}
