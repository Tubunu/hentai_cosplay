/// Represents categories, sorting options, and rating filters available on Iwara.tv
enum IwaraCategory {
  latest('最新发布', 'date', rating: null),
  trending('趋势热门', 'trending', rating: null),
  popularity('历史人气', 'popularity', rating: null),
  views('最多播放', 'views', rating: null),
  likes('最多点赞', 'likes', rating: null),
  ecchi('绅士 R18', 'date', rating: 'ecchi'),
  general('全年龄', 'date', rating: 'general');

  final String label;
  final String sort;
  final String? rating;

  const IwaraCategory(this.label, this.sort, {this.rating});
}
