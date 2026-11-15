// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/color_detector.dart';
import 'package:putt_physics_v1/services/color_mask.dart';
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('compare original HSV and current ColorScanner performance', () {
    const width = 640;
    const height = 360;
    const iterations = 20;

    final random = Random(20261111);
    final image = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final dark = random.nextInt(100) < 80;
        image.setPixelRgb(
          x,
          y,
          dark ? random.nextInt(64) : random.nextInt(256),
          dark ? random.nextInt(64) : random.nextInt(256),
          dark ? random.nextInt(64) : random.nextInt(256),
        );
      }
    }

    int original() {
      final combined = ColorMask(width: width, height: height);
      final yellowMask = ColorMask(width: width, height: height);
      final redMask = ColorMask(width: width, height: height);

      var redCount = 0;
      var yellowCount = 0;

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);
          final hsv = ColorDetector.rgbToHsv(
            red: pixel.r.toInt(),
            green: pixel.g.toInt(),
            blue: pixel.b.toInt(),
          );

          final isYellow = ColorDetector.isYellow(hsv);
          final isRed = ColorDetector.isRed(hsv);

          if (isYellow) yellowCount++;
          if (isRed) redCount++;

          final index = y * width + x;
          yellowMask.pixels[index] = isYellow;
          redMask.pixels[index] = isRed;
          combined.pixels[index] = isYellow || isRed;
        }
      }

      return redCount + yellowCount;
    }

    int current() {
      final result = ColorScanner.scan(image);
      return result.yellowPixels + result.redPixels;
    }

    expect(original(), current());

    var checksum = 0;

    for (var i = 0; i < 3; i++) {
      checksum += original();
      checksum += current();
    }

    final oldWatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      checksum += original();
    }
    oldWatch.stop();

    final newWatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      checksum += current();
    }
    newWatch.stop();

    final oldMs = oldWatch.elapsedMicroseconds / 1000 / iterations;
    final newMs = newWatch.elapsedMicroseconds / 1000 / iterations;

    print('COLOR PERFORMANCE original=${oldMs.toStringAsFixed(2)}ms');
    print('COLOR PERFORMANCE current=${newMs.toStringAsFixed(2)}ms');
    print('COLOR PERFORMANCE ratio=${(oldMs / newMs).toStringAsFixed(2)}x');
    print('COLOR PERFORMANCE checksum=$checksum');
  });
}
