/// Represents categories, genres, and rankings available on Hanime1.me
enum Hanime1Category {
  latest('最新上市', '/search?genre=裏番'),
  dailyRanking('本日排行', '/search?sort=本日排行'),
  weeklyRanking('本周排行', '/search?sort=本週排行'),
  monthlyRanking('本月排行', '/search?sort=本月排行'),
  allRanking('总排行榜', '/search?sort=總排行'),
  shortAnime('泡麵番', '/search?genre=泡麵番'),
  motionAnime('Motion Anime', '/search?genre=Motion Anime'),
  anime3D('3DCG', '/search?genre=3DCG'),
  anime25D('2.5D', '/search?genre=2.5D'),
  anime2D('2D動畫', '/search?genre=2D動畫'),
  aiGenerated('AI生成', '/search?genre=AI生成'),
  mmd('MMD', '/search?genre=MMD'),
  cosplay('Cosplay', '/search?genre=Cosplay'),
  doujin('同人作品', '/search?query=同人'),
  uncensored('無修正', '/search?query=無修正');

  final String label;
  final String path;
  const Hanime1Category(this.label, this.path);
}
