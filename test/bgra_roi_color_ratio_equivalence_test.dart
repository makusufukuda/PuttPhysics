import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/color_scanner.dart';
import 'package:putt_physics_v1/services/frame_extractor.dart';

void main() {
  test('BGRA direct ROI preserves original color ratios', () {
    const width = 240;
    const height = 180;
    const minX = 20;
    const minY = 15;
    const maxX = 220;
    const maxY = 165;

    final bytes = Uint8List(width * height * 4);

    // Blue background.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Red 40 x 40 region.
    for (var y = 50; y < 90; y++) {
      for (var x = 50; x < 90; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = 0;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final full = FrameExtractor.decodeFrame(frame)!;
    final cropped = FrameExtractor.decodeFrameRoi(
      frame,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    )!;

    final original = ColorScanner.scanRoi(
      full,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    final direct = ColorScanner.scanRoi(
      cropped,
      minX: 0,
      minY: 0,
      maxX: cropped.width,
      maxY: cropped.height,
      originalTotalPixels: width * height,
    );

    expect(direct.totalPixels, original.totalPixels);
    expect(direct.redPixels, original.redPixels);
    expect(direct.yellowPixels, original.yellowPixels);
    expect(direct.targetColorPixels, original.targetColorPixels);
    expect(direct.redRatio, original.redRatio);
    expect(direct.yellowRatio, original.yellowRatio);
    expect(direct.scannedPixels, original.scannedPixels);
    expect(direct.skippedDarkPixels, original.skippedDarkPixels);
  });
}
