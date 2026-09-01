/// Represents categories and sorting options available on Rule34Video.com
enum Rule34VideoCategory {
  latest('最新更新', '/latest-updates/'),
  popular('最受关注', '/most-popular/'),
  topRated('最高评分', '/top-rated/'),
  trending('热门推荐', '/');

  final String label;
  final String path;

  const Rule34VideoCategory(this.label, this.path);
}
