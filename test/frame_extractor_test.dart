import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/frame_extractor.dart';

void main() {
  test('BGRA8888 handles padded rows correctly', () {
    final bytes = Uint8List.fromList([
      0, 0, 255, 255, 99, 99, 99, 99,
      0, 255, 255, 255, 88, 88, 88, 88,
    ]);

    final frame = ExtractedVideoFrame(
      position: Duration.zero,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: 1,
      height: 2,
      bytesPerRow: 8,
    );

    final image = FrameExtractor.decodeFrame(frame)!;

    expect(image.getPixel(0, 0).r, 255);
    expect(image.getPixel(0, 0).g, 0);
    expect(image.getPixel(0, 0).b, 0);

    expect(image.getPixel(0, 1).r, 255);
    expect(image.getPixel(0, 1).g, 255);
    expect(image.getPixel(0, 1).b, 0);
  });

  test('BGRA8888 decodes red, yellow, and pink correctly', () {
    final bytes = Uint8List.fromList([
      0, 0, 255, 255,      // Red
      0, 255, 255, 255,    // Yellow
      180, 105, 255, 255,  // Pink (RGB: 255,105,180)
    ]);

    final frame = ExtractedVideoFrame(
      position: Duration.zero,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: 3,
      height: 1,
      bytesPerRow: 12,
    );

    final image = FrameExtractor.decodeFrame(frame)!;

    expect(image.width, 3);
    expect(image.height, 1);

    expect(image.getPixel(0, 0).r, 255);
    expect(image.getPixel(0, 0).g, 0);
    expect(image.getPixel(0, 0).b, 0);

    expect(image.getPixel(1, 0).r, 255);
    expect(image.getPixel(1, 0).g, 255);
    expect(image.getPixel(1, 0).b, 0);

    expect(image.getPixel(2, 0).r, 255);
    expect(image.getPixel(2, 0).g, 105);
    expect(image.getPixel(2, 0).b, 180);
  });

  test('BGRA ROI crop preserves original pixel colors', () {
    final bytes = Uint8List.fromList([
      // Row 0: red, yellow, pink, padding
      0, 0, 255, 255,
      0, 255, 255, 255,
      180, 105, 255, 255,
      99, 99, 99, 99,
      // Row 1: blue, green, white, padding
      255, 0, 0, 255,
      0, 255, 0, 255,
      255, 255, 255, 255,
      88, 88, 88, 88,
    ]);

    final frame = ExtractedVideoFrame(
      position: Duration.zero,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: 3,
      height: 2,
      bytesPerRow: 16,
    );

    final full = FrameExtractor.decodeFrame(frame)!;
    final cropped = img.copyCrop(
      full,
      x: 1,
      y: 0,
      width: 2,
      height: 2,
    );

    expect(cropped.width, 2);
    expect(cropped.height, 2);

    for (var y = 0; y < cropped.height; y++) {
      for (var x = 0; x < cropped.width; x++) {
        final expected = full.getPixel(x + 1, y);
        final actual = cropped.getPixel(x, y);

        expect(actual.r, expected.r);
        expect(actual.g, expected.g);
        expect(actual.b, expected.b);
        expect(actual.a, expected.a);
      }
    }

    expect(cropped.getPixel(0, 0).r, 255);
    expect(cropped.getPixel(0, 0).g, 255);
    expect(cropped.getPixel(0, 0).b, 0);

    expect(cropped.getPixel(1, 0).r, 255);
    expect(cropped.getPixel(1, 0).g, 105);
    expect(cropped.getPixel(1, 0).b, 180);
  });


  test('BGRA direct ROI matches full decode crop', () {
    final bytes = Uint8List.fromList([
      // Row 0: red, yellow, pink, padding
      0, 0, 255, 255,
      0, 255, 255, 255,
      180, 105, 255, 255,
      99, 99, 99, 99,
      // Row 1: blue, green, white, padding
      255, 0, 0, 255,
      0, 255, 0, 255,
      255, 255, 255, 255,
      88, 88, 88, 88,
    ]);

    final frame = ExtractedVideoFrame(
      position: Duration.zero,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: 3,
      height: 2,
      bytesPerRow: 16,
    );

    final full = FrameExtractor.decodeFrame(frame)!;
    final expected = img.copyCrop(
      full,
      x: 1,
      y: 0,
      width: 2,
      height: 2,
    );

    final actual = FrameExtractor.decodeFrameRoi(
      frame,
      minX: 1,
      minY: 0,
      maxX: 3,
      maxY: 2,
    )!;

    expect(actual.width, expected.width);
    expect(actual.height, expected.height);

    for (var y = 0; y < actual.height; y++) {
      for (var x = 0; x < actual.width; x++) {
        final a = actual.getPixel(x, y);
        final e = expected.getPixel(x, y);

        expect(a.r, e.r, reason: 'R at ($x, $y)');
        expect(a.g, e.g, reason: 'G at ($x, $y)');
        expect(a.b, e.b, reason: 'B at ($x, $y)');
        expect(a.a, e.a, reason: 'A at ($x, $y)');
      }
    }
  });


  test('BGRA ROI handles image boundaries', () {
    final bytes = Uint8List.fromList([
      // Row 0: red, yellow, padding
      0, 0, 255, 255,
      0, 255, 255, 255,
      99, 99, 99, 99,
      // Row 1: blue, green, padding
      255, 0, 0, 255,
      0, 255, 0, 255,
      88, 88, 88, 88,
    ]);

    final frame = ExtractedVideoFrame(
      position: Duration.zero,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: 2,
      height: 2,
      bytesPerRow: 12,
    );

    final full = FrameExtractor.decodeFrame(frame)!;

    // ROI extending beyond all four edges.
    final clipped = FrameExtractor.decodeFrameRoi(
      frame,
      minX: -10,
      minY: -10,
      maxX: 10,
      maxY: 10,
    )!;

    expect(clipped.width, 2);
    expect(clipped.height, 2);

    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 2; x++) {
        final actual = clipped.getPixel(x, y);
        final expected = full.getPixel(x, y);
        expect(actual.r, expected.r);
        expect(actual.g, expected.g);
        expect(actual.b, expected.b);
        expect(actual.a, expected.a);
      }
    }

    // Bottom-right corner.
    final corner = FrameExtractor.decodeFrameRoi(
      frame,
      minX: 1,
      minY: 1,
      maxX: 2,
      maxY: 2,
    )!;

    expect(corner.width, 1);
    expect(corner.height, 1);
    expect(corner.getPixel(0, 0).r, 0);
    expect(corner.getPixel(0, 0).g, 255);
    expect(corner.getPixel(0, 0).b, 0);

    // Empty ROI.
    expect(
      FrameExtractor.decodeFrameRoi(
        frame,
        minX: 1,
        minY: 0,
        maxX: 1,
        maxY: 2,
      ),
      isNull,
    );

    // Completely outside the image.
    expect(
      FrameExtractor.decodeFrameRoi(
        frame,
        minX: 10,
        minY: 10,
        maxX: 20,
        maxY: 20,
      ),
      isNull,
    );
  });

}
