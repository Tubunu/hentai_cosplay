import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/models/app_config.dart';
import 'package:hentai_cosplay_downloader/providers/local_video_provider.dart';
import 'package:hentai_cosplay_downloader/utils/format_utils.dart';

void main() {
  group('AppConfig disguiseBiometricUnlock Tests', () {
    test('Default value is false', () {
      final config = AppConfig();
      expect(config.disguiseBiometricUnlock, isFalse);
    });

    test('copyWith updates disguiseBiometricUnlock', () {
      final config = AppConfig();
      final updated = config.copyWith(disguiseBiometricUnlock: true);
      expect(updated.disguiseBiometricUnlock, isTrue);
      expect(config.disguiseBiometricUnlock, isFalse);
    });

    test('fromJson and toJson roundtrip preserves disguiseBiometricUnlock', () {
      final config = AppConfig(disguiseBiometricUnlock: true);
      final json = config.toJson();
      expect(json['disguiseBiometricUnlock'], isTrue);

      final revived = AppConfig.fromJson(json);
      expect(revived.disguiseBiometricUnlock, isTrue);
      expect(revived, equals(config));
    });
  });

  group('FormatUtils Tests', () {
    test('formatBytes handles various ranges correctly', () {
      expect(FormatUtils.formatBytes(0), '0 B');
      expect(FormatUtils.formatBytes(-100), '0 B');
      expect(FormatUtils.formatBytes(512), '512 B');
      expect(FormatUtils.formatBytes(1024), '1.0 KB');
      expect(FormatUtils.formatBytes(1536), '1.5 KB');
      expect(FormatUtils.formatBytes(1024 * 1024), '1.0 MB');
      expect(FormatUtils.formatBytes(50 * 1024 * 1024), '50.0 MB');
      expect(FormatUtils.formatBytes(1024 * 1024 * 1024), '1.00 GB');
      expect(FormatUtils.formatBytes((2.5 * 1024 * 1024 * 1024).round()), '2.50 GB');
    });

    test('LocalVideoProvider formattedTotalSize uses FormatUtils correctly', () {
      final prov = LocalVideoProvider();
      expect(prov.formattedTotalSize, '0 B');
    });
  });
}
