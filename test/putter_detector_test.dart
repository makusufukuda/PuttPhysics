import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:putt_physics_v1/services/putter_detector.dart';

void main() {
  group('PutterDetector ROI', () {
    late img.Image image;

    setUp(() {
      image = img.Image(width: 300, height: 200);

      // Two pink markers, each 20 x 12 pixels.
      for (var y = 120; y < 132; y++) {
        for (var x = 80; x < 100; x++) {
          image.setPixelRgb(x, y, 255, 0, 150);
        }
        for (var x = 140; x < 160; x++) {
          image.setPixelRgb(x, y, 255, 0, 150);
        }
      }
    });

    test('detects markers without ROI', () {
      final candidates = PutterDetector.detectDecoded(image);

      expect(candidates, hasLength(1));
      expect(candidates.single.centerX, closeTo(119.5, 0.001));
      expect(candidates.single.centerY, closeTo(125.5, 0.001));
    });

    test('detects markers inside ROI with original coordinates', () {
      final candidates = PutterDetector.detectDecoded(
        image,
        minX: 60,
        minY: 100,
        maxX: 180,
        maxY: 150,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.centerX, closeTo(119.5, 0.001));
      expect(candidates.single.centerY, closeTo(125.5, 0.001));
    });

    test('excludes markers outside ROI', () {
      final candidates = PutterDetector.detectDecoded(
        image,
        minY: 0,
        maxY: 100,
      );

      expect(candidates, isEmpty);
    });
  });
}
