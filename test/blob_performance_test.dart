import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/blob_analyzer.dart';
import 'package:putt_physics_v1/services/color_mask.dart';

void main() {
  test('compare legacy and three-mask performance', () {
    const width = 640;
    const height = 360;
    const iterations = 20;

    final combined = ColorMask(width: width, height: height);
    final yellow = ColorMask(width: width, height: height);
    final red = ColorMask(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        final isYellow = (x ~/ 40 + y ~/ 40) % 7 == 0;
        final isRed = (x ~/ 40 + y ~/ 40) % 11 == 0;

        yellow.pixels[index] = isYellow;
        red.pixels[index] = isRed;
        combined.pixels[index] = isYellow || isRed;
      }
    }

    void legacy() {
      BlobAnalyzer.extractBlobs(combined, minimumPixelCount: 10);
      BlobAnalyzer.extractBlobs(yellow, minimumPixelCount: 10);
      BlobAnalyzer.extractBlobs(red, minimumPixelCount: 10);
    }

    void optimized() {
      BlobAnalyzer.extractThreeMasks(
        combinedMask: combined,
        yellowMask: yellow,
        redMask: red,
        minimumPixelCount: 10,
      );
    }

    // Warm-up
    legacy();
    optimized();

    final oldWatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      legacy();
    }
    oldWatch.stop();

    final newWatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      optimized();
    }
    newWatch.stop();

    final oldMs = oldWatch.elapsedMicroseconds / 1000 / iterations;
    final newMs = newWatch.elapsedMicroseconds / 1000 / iterations;

    print('BLOB PERFORMANCE legacy=${oldMs.toStringAsFixed(2)}ms');
    print('BLOB PERFORMANCE optimized=${newMs.toStringAsFixed(2)}ms');
    print('BLOB PERFORMANCE ratio=${(oldMs / newMs).toStringAsFixed(2)}x');
  });
}
