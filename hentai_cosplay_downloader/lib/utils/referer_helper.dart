import '../models/album_item.dart';

class RefererHelper {
  static const String defaultReferer = 'https://zh.hentai-cosplay-xxx.com/';

  static String getReferer(String url, {MediaSourceType? sourceType}) {
    if (sourceType != null) {
      switch (sourceType) {
        case MediaSourceType.hc:
          return 'https://zh.hentai-cosplay-xxx.com/';
        case MediaSourceType.mzt:
          return 'https://mzt.111404.xyz/';
        case MediaSourceType.misskon:
          return 'https://misskon.com/';
        case MediaSourceType.coomer:
          return 'https://coomer.st/';
        case MediaSourceType.kuraa:
          return 'https://kuraa.org/';
        case MediaSourceType.exhentai:
          return 'https://ex.810114.xyz/';
        case MediaSourceType.pixibb:
          return 'https://pixibb.com/';
        case MediaSourceType.cosplaytele:
          return 'https://cosplaytele.com/';
        case MediaSourceType.nucosplay:
          return 'https://nucosplay.com/';
        case MediaSourceType.cosvault:
          return 'https://cosvault.top/';
        case MediaSourceType.galleryepic:
          return 'https://galleryepic.xyz/';
        case MediaSourceType.nsfwpub:
          return 'https://nsfwpub.com/';
      }
    }

    if (url.contains('mzt.111404.xyz') || url.contains('1258012.xyz') || url.contains('tgproxy')) {
      return 'https://mzt.111404.xyz/';
    } else if (url.contains('misskon.com')) {
      return 'https://misskon.com/';
    } else if (url.contains('coomer.st') || url.contains('coomer.su') || url.contains('c1.coomer') || url.contains('c2.coomer') || url.contains('c3.coomer')) {
      return 'https://coomer.st/';
    } else if (url.contains('kuraa.org') || url.contains('kuraa.cc')) {
      return 'https://kuraa.org/';
    } else if (url.contains('pixibb.com')) {
      return 'https://pixibb.com/';
    } else if (url.contains('cosplaytele.com')) {
      return 'https://cosplaytele.com/';
    } else if (url.contains('nucosplay.com')) {
      return 'https://nucosplay.com/';
    } else if (url.contains('cosvault.top')) {
      return 'https://cosvault.top/';
    } else if (url.contains('galleryepic.xyz')) {
      return 'https://galleryepic.xyz/';
    } else if (url.contains('nsfwpub.com')) {
      return 'https://nsfwpub.com/';
    } else if (url.contains('exhentai.org') || url.contains('e-hentai.org') || url.contains('810114.xyz')) {
      return 'https://ex.810114.xyz/';
    } else if (url.contains('hohoj.tv') || url.contains('ggjav.com')) {
      return 'https://hohoj.tv/';
    }

    return defaultReferer;
  }

  static Map<String, String> buildImageHeaders(String url, {MediaSourceType? sourceType, Map<String, String>? customHeaders}) {
    if (customHeaders != null && customHeaders.isNotEmpty) {
      return customHeaders;
    }
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Referer': getReferer(url, sourceType: sourceType),
      'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
    };
  }
}
