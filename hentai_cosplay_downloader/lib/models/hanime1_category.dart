/// Represents categories and rankings available on Hanime1.me
enum Hanime1Category {
  latest('最新上市', '/search?genre=裏番'),
  monthlyRanking('月度排行', '/ranking?type=monthly'),
  weeklyRanking('周排行榜', '/ranking?type=weekly'),
  allRanking('总排行榜', '/ranking?type=all'),
  shortAnime('泡麵番', '/search?genre=泡麵番'),
  anime3D('3D動畫', '/search?genre=3D動畫'),
  doujin('同人作品', '/search?genre=同人作品'),
  cosplay('Cosplay', '/search?genre=Cosplay'),
  uncensored('無修正', '/search?genre=無修正');

  final String label;
  final String path;
  const Hanime1Category(this.label, this.path);
}
