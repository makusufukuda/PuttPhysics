import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/blob_analyzer.dart';
import 'package:putt_physics_v1/services/color_mask.dart';

void main() {
  test('extracts connected pixels and calculates centroid', () {
    final mask = ColorMask(width: 5, height: 3);

    mask.setPixel(1, 1, true);
    mask.setPixel(2, 1, true);
    mask.setPixel(3, 1, true);

    final blobs = BlobAnalyzer.extractBlobs(mask);

    expect(blobs, hasLength(1));
    expect(blobs.single.pixelCount, 3);
    expect(blobs.single.centroidX, 2.0);
    expect(blobs.single.centroidY, 1.0);
  });

  test('combines adjacent red and yellow pixels', () {
    final combined = ColorMask(width: 4, height: 1);
    final yellow = ColorMask(width: 4, height: 1);
    final red = ColorMask(width: 4, height: 1);

    yellow.setPixel(1, 0, true);
    red.setPixel(2, 0, true);
    combined.setPixel(1, 0, true);
    combined.setPixel(2, 0, true);

    final both = BlobAnalyzer.extractBlobs(combined);
    final yellowOnly = BlobAnalyzer.extractBlobs(yellow);
    final redOnly = BlobAnalyzer.extractBlobs(red);

    expect(both, hasLength(1));
    expect(both.single.pixelCount, 2);
    expect(both.single.centroidX, 1.5);
    expect(yellowOnly, hasLength(1));
    expect(redOnly, hasLength(1));
  });

  test('detects a single visible color', () {
    for (final color in ['red', 'yellow']) {
      final combined = ColorMask(width: 4, height: 1);

      combined.setPixel(1, 0, true);
      combined.setPixel(2, 0, true);

      final blobs = BlobAnalyzer.extractBlobs(combined);

      expect(blobs, hasLength(1), reason: color);
      expect(blobs.single.pixelCount, 2);
      expect(blobs.single.centroidX, 1.5);
    }
  });

  test('keeps separate regions independent', () {
    final mask = ColorMask(width: 5, height: 1);
    mask.setPixel(0, 0, true);
    mask.setPixel(4, 0, true);

    final blobs = BlobAnalyzer.extractBlobs(mask);

    expect(blobs, hasLength(2));
    expect(blobs[0].pixelCount, 1);
    expect(blobs[1].pixelCount, 1);
  });

  test('excludes regions below minimum pixel count', () {
    final mask = ColorMask(width: 4, height: 1);
    mask.setPixel(0, 0, true);
    mask.setPixel(2, 0, true);
    mask.setPixel(3, 0, true);

    final blobs = BlobAnalyzer.extractBlobs(
      mask,
      minimumPixelCount: 2,
    );

    expect(blobs, hasLength(1));
    expect(blobs.single.pixelCount, 2);
    expect(blobs.single.minX, 2);
  });
}
