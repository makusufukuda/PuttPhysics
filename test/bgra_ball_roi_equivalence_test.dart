import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/models/blob.dart';
import 'package:putt_physics_v1/services/blob_analyzer.dart';
import 'package:putt_physics_v1/services/blob_filter.dart';
import 'package:putt_physics_v1/services/color_scanner.dart';
import 'package:putt_physics_v1/services/frame_extractor.dart';

void main() {
  test('BGRA direct ROI preserves ball color scanning', () {
    const width = 160;
    const height = 120;
    const minX = 31;
    const minY = 22;
    const maxX = 131;
    const maxY = 102;

    final random = Random(20261116);
    final bytes = Uint8List(width * height * 4);

    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = random.nextInt(256);
      bytes[i + 1] = random.nextInt(256);
      bytes[i + 2] = random.nextInt(256);
      bytes[i + 3] = 255;
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
    );

    expect(direct.yellowPixels, original.yellowPixels);
    expect(direct.redPixels, original.redPixels);
    expect(direct.scannedPixels, original.scannedPixels);
    expect(direct.skippedDarkPixels, original.skippedDarkPixels);

    for (var y = 0; y < cropped.height; y++) {
      for (var x = 0; x < cropped.width; x++) {
        expect(
          direct.mask.getPixel(x, y),
          original.mask.getPixel(x + minX, y + minY),
        );
        expect(
          direct.redMask.getPixel(x, y),
          original.redMask.getPixel(x + minX, y + minY),
        );
        expect(
          direct.yellowMask.getPixel(x, y),
          original.yellowMask.getPixel(x + minX, y + minY),
        );
      }
    }
  });

  test('BGRA direct ROI preserves blob coordinates', () {
    const width = 160;
    const height = 120;
    const minX = 31;
    const minY = 22;
    const maxX = 131;
    const maxY = 102;

    final bytes = Uint8List(width * height * 4);

    // Blue background, outside the red/yellow detection range.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 1] = 0;
      bytes[i + 2] = 0;
      bytes[i + 3] = 255;
    }

    void paintRect(
      int x1, int y1, int x2, int y2, {
      required bool yellow,
    }) {
      for (var y = y1; y < y2; y++) {
        for (var x = x1; x < x2; x++) {
          final i = (y * width + x) * 4;
          bytes[i] = 0;
          bytes[i + 1] = yellow ? 255 : 0;
          bytes[i + 2] = 255;
        }
      }
    }

    paintRect(45, 35, 65, 55, yellow: false);
    paintRect(85, 65, 105, 85, yellow: true);

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
    );

    final oldBlobs = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: original.mask,
      yellowMask: original.yellowMask,
      redMask: original.redMask,
      minimumPixelCount: 1,
    );

    final newBlobs = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: direct.mask,
      yellowMask: direct.yellowMask,
      redMask: direct.redMask,
      minimumPixelCount: 1,
    );

    void compare(List<Blob> expected, List<Blob> actual) {
      expect(actual.length, expected.length);

      for (var i = 0; i < expected.length; i++) {
        final e = expected[i];
        final a = actual[i];

        expect(a.pixelCount, e.pixelCount);
        expect(a.minX + minX, e.minX);
        expect(a.maxX + minX, e.maxX);
        expect(a.minY + minY, e.minY);
        expect(a.maxY + minY, e.maxY);
        expect(a.centroidX + minX, closeTo(e.centroidX, 0.001));
        expect(a.centroidY + minY, closeTo(e.centroidY, 0.001));
      }
    }

    compare(oldBlobs.$1, newBlobs.$1);
    compare(oldBlobs.$2, newBlobs.$2);
    compare(oldBlobs.$3, newBlobs.$3);
  });


  test('BGRA direct ROI preserves ball candidates', () {
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

    void paintRect(
      int x1, int y1, int x2, int y2, {
      required bool yellow,
    }) {
      for (var y = y1; y < y2; y++) {
        for (var x = x1; x < x2; x++) {
          final i = (y * width + x) * 4;
          bytes[i] = 0;
          bytes[i + 1] = yellow ? 255 : 0;
          bytes[i + 2] = 255;
        }
      }
    }

    // Normal red ball and horizontally elongated yellow region.
    paintRect(50, 50, 90, 90, yellow: false);
    paintRect(120, 105, 190, 125, yellow: true);

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
    );

    final oldBlobs = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: original.mask,
      yellowMask: original.yellowMask,
      redMask: original.redMask,
      minimumPixelCount: 1,
    );

    final newBlobs = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: direct.mask,
      yellowMask: direct.yellowMask,
      redMask: direct.redMask,
      minimumPixelCount: 1,
    );

    final oldCandidates = BlobFilter.filter(oldBlobs.$1);
    final newCandidates = BlobFilter.filter(newBlobs.$1);

    expect(oldCandidates.length, 2);
    expect(newCandidates.length, oldCandidates.length);

    expect(
      oldCandidates.any((c) => c.isMotionBlur),
      isTrue,
    );
    expect(
      oldCandidates.any((c) => !c.isMotionBlur),
      isTrue,
    );

    for (var i = 0; i < oldCandidates.length; i++) {
      final expected = oldCandidates[i];
      final actual = newCandidates[i];

      expect(actual.centerX + minX, closeTo(expected.centerX, 0.001));
      expect(actual.centerY + minY, closeTo(expected.centerY, 0.001));
      expect(actual.radius, closeTo(expected.radius, 0.001));
      expect(actual.confidence, closeTo(expected.confidence, 0.000001));
      expect(actual.isMotionBlur, expected.isMotionBlur);
      expect(
        actual.isCombinedRedYellow,
        expected.isCombinedRedYellow,
      );
    }
  });

}
