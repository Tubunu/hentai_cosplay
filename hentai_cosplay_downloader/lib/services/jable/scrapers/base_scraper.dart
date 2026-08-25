import '../../../models/jable_video_item.dart';

abstract class BaseScraper {
  String get siteName;
  String get urlRoot;

  /// Fetches the categories for the website.
  Future<List<CategoryModel>> fetchCategories();

  /// Fetches a paginated list of videos from a category URL or listing page.
  Future<List<VideoCardModel>> fetchPage(String url);

  /// Performs a search and returns video matches.
  Future<List<VideoCardModel>> search(String query);

  /// Builds a paginated URL for standard listing pagination.
  String buildPageUrl(String baseUrl, int page);

  /// Parses a single video details page to extract the video title, thumbnail, and final master M3U8 URL.
  Future<VideoDetailModel> parseVideoDetail(String videoUrl);
}
