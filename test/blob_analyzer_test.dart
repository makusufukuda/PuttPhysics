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

  test('baseline: mixed red and yellow regions', () {
    final mask = ColorMask(width: 7, height: 3);

    for (final point in [(1, 0), (2, 0), (2, 1), (5, 2)]) {
      mask.setPixel(point.$1, point.$2, true);
    }

    final blobs = BlobAnalyzer.extractBlobs(mask);

    expect(blobs, hasLength(2));

    expect(blobs[0].pixelCount, 3);
    expect(blobs[0].minX, 1);
    expect(blobs[0].minY, 0);
    expect(blobs[0].maxX, 2);
    expect(blobs[0].maxY, 1);
    expect(blobs[0].centroidX, closeTo(5 / 3, 0.000001));
    expect(blobs[0].centroidY, closeTo(1 / 3, 0.000001));

    expect(blobs[1].pixelCount, 1);
    expect(blobs[1].minX, 5);
    expect(blobs[1].minY, 2);
    expect(blobs[1].maxX, 5);
    expect(blobs[1].maxY, 2);
    expect(blobs[1].centroidX, 5);
    expect(blobs[1].centroidY, 2);
  });

  test('three-mask results match legacy extraction', () {
    final combined = ColorMask(width: 9, height: 5);
    final yellow = ColorMask(width: 9, height: 5);
    final red = ColorMask(width: 9, height: 5);

    final yellowPoints = [
      (1, 0), (2, 0), (2, 1),
      (6, 3), (6, 4),
    ];
    final redPoints = [
      (3, 1), (3, 2),
      (7, 3), (8, 3),
    ];

    for (final point in yellowPoints) {
      yellow.setPixel(point.$1, point.$2, true);
      combined.setPixel(point.$1, point.$2, true);
    }

    for (final point in redPoints) {
      red.setPixel(point.$1, point.$2, true);
      combined.setPixel(point.$1, point.$2, true);
    }

    final oldResults = [
      BlobAnalyzer.extractBlobs(combined),
      BlobAnalyzer.extractBlobs(yellow),
      BlobAnalyzer.extractBlobs(red),
    ];

    final newResults = BlobAnalyzer.extractThreeMasks(
      combinedMask: combined,
      yellowMask: yellow,
      redMask: red,
    );

    final newLists = [
      newResults.$1,
      newResults.$2,
      newResults.$3,
    ];

    for (var channel = 0; channel < 3; channel++) {
      final oldBlobs = oldResults[channel];
      final newBlobs = newLists[channel];

      expect(newBlobs.length, oldBlobs.length);

      for (var i = 0; i < oldBlobs.length; i++) {
        final a = oldBlobs[i];
        final b = newBlobs[i];

        expect(b.pixelCount, a.pixelCount);
        expect(b.minX, a.minX);
        expect(b.minY, a.minY);
        expect(b.maxX, a.maxX);
        expect(b.maxY, a.maxY);
        expect(b.centroidX, a.centroidX);
        expect(b.centroidY, a.centroidY);
      }
    }
  });
}
