import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/color_detector.dart';
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('ColorScanner matches original HSV classification', () {
    final random = Random(20261111);
    final image = img.Image(width: 128, height: 128);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(
          x,
          y,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
    }

    final result = ColorScanner.scan(image);

    var expectedRed = 0;
    var expectedYellow = 0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final hsv = ColorDetector.rgbToHsv(
          red: pixel.r.toInt(),
          green: pixel.g.toInt(),
          blue: pixel.b.toInt(),
        );

        final red = ColorDetector.isRed(hsv);
        final yellow = ColorDetector.isYellow(hsv);

        if (red) expectedRed++;
        if (yellow) expectedYellow++;

        expect(result.redMask.getPixel(x, y), red);
        expect(result.yellowMask.getPixel(x, y), yellow);
        expect(result.mask.getPixel(x, y), red || yellow);
      }
    }

    expect(result.redPixels, expectedRed);
    expect(result.yellowPixels, expectedYellow);
  });
}
