import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hentai_cosplay_downloader/ui/pages/video/video_player_page.dart';

void main() {
  group('VideoScaleMode Enum Tests', () {
    test('VideoScaleMode has all expected values and cycles correctly', () {
      expect(VideoScaleMode.values.length, equals(5));
      expect(VideoScaleMode.contain.label, equals('原始比例'));
      expect(VideoScaleMode.cover.label, equals('裁剪铺满'));
      expect(VideoScaleMode.stretch.label, equals('拉伸铺满'));
      expect(VideoScaleMode.ratio16_9.label, equals('16:9'));
      expect(VideoScaleMode.ratio4_3.label, equals('4:3'));

      // Test cycle
      expect(VideoScaleMode.contain.next(), equals(VideoScaleMode.cover));
      expect(VideoScaleMode.cover.next(), equals(VideoScaleMode.stretch));
      expect(VideoScaleMode.stretch.next(), equals(VideoScaleMode.ratio16_9));
      expect(VideoScaleMode.ratio16_9.next(), equals(VideoScaleMode.ratio4_3));
      expect(VideoScaleMode.ratio4_3.next(), equals(VideoScaleMode.contain));
    });

    testWidgets('AspectRatio under Center preserves aspect ratio in portrait screen constraints', (tester) async {
      // Demonstrating that Stack + Center + AspectRatio correctly respects 16:9 ratio
      // in portrait screen constraints (360x800)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 800,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(key: const Key('video_box'), color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final boxFinder = find.byKey(const Key('video_box'));
      expect(boxFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(boxFinder);
      expect(renderBox.size.width, equals(360.0));
      // 360 / (16 / 9) = 202.5
      expect(renderBox.size.height, closeTo(202.5, 0.01));
    });

    testWidgets('AspectRatio under Center preserves aspect ratio in landscape screen constraints', (tester) async {
      // Demonstrating that Stack + Center + AspectRatio correctly respects 16:9 ratio
      // in landscape screen constraints (800x360)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(key: const Key('video_box_landscape'), color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final boxFinder = find.byKey(const Key('video_box_landscape'));
      expect(boxFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(boxFinder);
      expect(renderBox.size.height, equals(360.0));
      // 360 * (16 / 9) = 640.0
      expect(renderBox.size.width, closeTo(640.0, 0.01));
    });
  });
}
