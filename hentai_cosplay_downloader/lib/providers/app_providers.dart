import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'av123_browse_provider.dart';
import 'browse_provider.dart';
import 'browsing_history_provider.dart';
import 'coomer_browse_provider.dart';
import 'cosplayporntube_browse_provider.dart';
import 'cosplaytele_browse_provider.dart';
import 'cosvault_browse_provider.dart';
import 'cosxplay_browse_provider.dart';
import 'disguise_provider.dart';
import 'download_provider.dart';
import 'eporner_browse_provider.dart';
import 'exhentai_browse_provider.dart';
import 'favorite_provider.dart';
import 'gallery_provider.dart';
import 'galleryepic_browse_provider.dart';
import 'hanime1_browse_provider.dart';
import 'hohoj_browse_provider.dart';
import 'history_provider.dart';
import 'hqporner_browse_provider.dart';
import 'iwara_browse_provider.dart';
import 'jable_browse_provider.dart';
import 'jable_download_provider.dart';
import 'javguru_browse_provider.dart';
import 'javmost_browse_provider.dart';
import 'kuraa_browse_provider.dart';
import 'local_jable_provider.dart';
import 'local_video_provider.dart';
import 'memojav_browse_provider.dart';
import 'misskon_browse_provider.dart';
import 'mzt_browse_provider.dart';
import 'njav_browse_provider.dart';
import 'nsfwpub_browse_provider.dart';
import 'nucosplay_browse_provider.dart';
import 'pinse_browse_provider.dart';
import 'pixibb_browse_provider.dart';
import 'pornbox_browse_provider.dart';
import 'pornhub_browse_provider.dart';
import 'rule34video_browse_provider.dart';
import 'settings_provider.dart';
import 'spankbang_browse_provider.dart';
import 'thothub_browse_provider.dart';
import 'twitter_browse_provider.dart';
import 'video_browse_provider.dart';
import 'vjav_browse_provider.dart';
import 'xhamster_browse_provider.dart';
import 'xnxx_browse_provider.dart';
import 'xvideos_browse_provider.dart';

/// Modular Provider Registration Architecture
/// Separates core operational providers from third-party media site browsing providers.
class AppProviders {
  /// Core operational providers that manage app lifecycle, storage, downloads, and user settings.
  static List<SingleChildWidget> get coreProviders => [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => JableDownloadProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => BrowsingHistoryProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
        ChangeNotifierProvider(create: (_) => LocalVideoProvider()),
        ChangeNotifierProvider(create: (_) => LocalJableProvider()),
        ChangeNotifierProvider(
          create: (ctx) => DisguiseProvider(
            disguiseMode: ctx.read<SettingsProvider>().config.disguiseMode,
          ),
        ),
      ];

  /// Media site browsing providers, instantiated on-demand (lazy) when users navigate to their tabs.
  static List<SingleChildWidget> get siteBrowseProviders => [
        ChangeNotifierProvider(create: (_) => BrowseProvider()),
        ChangeNotifierProvider(create: (_) => MztBrowseProvider()),
        ChangeNotifierProvider(create: (_) => VideoBrowseProvider()),
        ChangeNotifierProvider(create: (_) => MisskonBrowseProvider()),
        ChangeNotifierProvider(create: (_) => CoomerBrowseProvider()),
        ChangeNotifierProvider(create: (_) => PinseBrowseProvider()),
        ChangeNotifierProvider(create: (_) => PornboxBrowseProvider()),
        ChangeNotifierProvider(create: (_) => KuraaBrowseProvider()),
        ChangeNotifierProvider(create: (_) => TwitterBrowseProvider()),
        ChangeNotifierProvider(create: (_) => ExHentaiBrowseProvider()),
        ChangeNotifierProvider(create: (_) => PixibbBrowseProvider()),
        ChangeNotifierProvider(create: (_) => CosplayteleBrowseProvider()),
        ChangeNotifierProvider(create: (_) => NucosplayBrowseProvider()),
        ChangeNotifierProvider(create: (_) => CosvaultBrowseProvider()),
        ChangeNotifierProvider(create: (_) => GalleryepicBrowseProvider()),
        ChangeNotifierProvider(create: (_) => Hanime1BrowseProvider()),
        ChangeNotifierProvider(create: (_) => IwaraBrowseProvider()),
        ChangeNotifierProvider(create: (_) => Rule34VideoBrowseProvider()),
        ChangeNotifierProvider(create: (_) => EpornerBrowseProvider()),
        ChangeNotifierProvider(create: (_) => HqpornerBrowseProvider()),
        ChangeNotifierProvider(create: (_) => SpankbangBrowseProvider()),
        ChangeNotifierProvider(create: (_) => PornhubBrowseProvider()),
        ChangeNotifierProvider(create: (_) => XVideosBrowseProvider()),
        ChangeNotifierProvider(create: (_) => CosxplayBrowseProvider()),
        ChangeNotifierProvider(create: (_) => CosplayporntubeBrowseProvider()),
        ChangeNotifierProvider(create: (_) => XhamsterBrowseProvider()),
        ChangeNotifierProvider(create: (_) => XnxxBrowseProvider()),
        ChangeNotifierProvider(create: (_) => NsfwpubBrowseProvider()),
        ChangeNotifierProvider(create: (_) => ThothubBrowseProvider()),
        ChangeNotifierProvider(create: (_) => NjavBrowseProvider()),
        ChangeNotifierProvider(create: (_) => VjavBrowseProvider()),
        ChangeNotifierProvider(create: (_) => JavguruBrowseProvider()),
        ChangeNotifierProvider(create: (_) => Av123BrowseProvider()),
        ChangeNotifierProvider(create: (_) => JavmostBrowseProvider()),
        ChangeNotifierProvider(create: (_) => MemojavBrowseProvider()),
        ChangeNotifierProvider(create: (_) => HohojBrowseProvider()),
        ChangeNotifierProvider(create: (_) => JableBrowseProvider()),
      ];

  /// Full list of all registered providers for MultiProvider root.
  static List<SingleChildWidget> get allProviders => [
        ...coreProviders,
        ...siteBrowseProviders,
      ];
}
