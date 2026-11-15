import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/frame_extractor.dart';

// ignore_for_file: avoid_print

void main() {
  test('compare full BGRA decode and direct ROI decode', () {
    const width = 1920;
    const height = 1080;
    const iterations = 10;

    final bytes = Uint8List(width * height * 4);

    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 80;
      bytes[i + 1] = 120;
      bytes[i + 2] = 200;
      bytes[i + 3] = 255;
    }

    final frame = ExtractedVideoFrame(
      position: Duration.zero,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    int fullDecode() {
      final image = FrameExtractor.decodeFrame(frame)!;
      return image.getPixel(0, 0).r.toInt();
    }

    int smallRoi() {
      final image = FrameExtractor.decodeFrameRoi(
        frame,
        minX: 800,
        minY: 400,
        maxX: 1120,
        maxY: 640,
      )!;
      return image.getPixel(0, 0).r.toInt();
    }

    int largeRoi() {
      final image = FrameExtractor.decodeFrameRoi(
        frame,
        minX: 0,
        minY: 680,
        maxX: 1920,
        maxY: 1080,
      )!;
      return image.getPixel(0, 0).r.toInt();
    }

    for (var i = 0; i < 3; i++) {
      fullDecode();
      smallRoi();
      largeRoi();
    }

    double measure(int Function() action) {
      var checksum = 0;
      final watch = Stopwatch()..start();

      for (var i = 0; i < iterations; i++) {
        checksum += action();
      }

      watch.stop();
      expect(checksum, 200 * iterations);
      return watch.elapsedMicroseconds / 1000 / iterations;
    }

    final fullMs = measure(fullDecode);
    final smallMs = measure(smallRoi);
    final largeMs = measure(largeRoi);

    print('BGRA PERFORMANCE full=${fullMs.toStringAsFixed(2)}ms');
    print('BGRA PERFORMANCE smallROI=${smallMs.toStringAsFixed(2)}ms');
    print('BGRA PERFORMANCE largeROI=${largeMs.toStringAsFixed(2)}ms');
    print(
      'BGRA PERFORMANCE smallSpeedup='
      '${(fullMs / smallMs).toStringAsFixed(2)}x',
    );
    print(
      'BGRA PERFORMANCE largeSpeedup='
      '${(fullMs / largeMs).toStringAsFixed(2)}x',
    );
  });
}
