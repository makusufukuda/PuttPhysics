import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/blob.dart';
import 'package:putt_physics_v1/services/blob_filter.dart';

void main() {
  group('BlobFilter', () {
    test('accepts normal round ball candidate', () {
      const blob = Blob(
        minX: 100,
        minY: 100,
        maxX: 139,
        maxY: 139,
        centroidX: 119.5,
        centroidY: 119.5,
        pixelCount: 1000,
      );

      final candidates = BlobFilter.filter([blob]);

      expect(candidates, hasLength(1));
      expect(candidates.first.isMotionBlur, isFalse);
    });

    test('accepts horizontal motion blur candidate', () {
      // Similar to the observed high-speed blob around frame 72:
      // approximately 130 x 22 pixels.
      const blob = Blob(
        minX: 100,
        minY: 100,
        maxX: 229,
        maxY: 121,
        centroidX: 164.5,
        centroidY: 110.5,
        pixelCount: 1307,
      );

      final candidates = BlobFilter.filter([blob]);

      expect(candidates, hasLength(1));

      final candidate = candidates.first;

      expect(candidate.isMotionBlur, isTrue);
      expect(candidate.centerX, 164.5);
      expect(candidate.centerY, 110.5);
      expect(candidate.radius, 11.0);
    });

    test('rejects very thin horizontal noise', () {
      const blob = Blob(
        minX: 100,
        minY: 100,
        maxX: 229,
        maxY: 106,
        centroidX: 164.5,
        centroidY: 103.0,
        pixelCount: 500,
      );

      final candidates = BlobFilter.filter([blob]);

      expect(candidates, isEmpty);
    });

    test('rejects motion blur candidate with low fill ratio', () {
      const blob = Blob(
        minX: 100,
        minY: 100,
        maxX: 229,
        maxY: 121,
        centroidX: 164.5,
        centroidY: 110.5,
        pixelCount: 500,
      );

      final candidates = BlobFilter.filter([blob]);

      expect(candidates, isEmpty);
    });

    test('rejects excessively wide horizontal blob', () {
      const blob = Blob(
        minX: 100,
        minY: 100,
        maxX: 299,
        maxY: 121,
        centroidX: 199.5,
        centroidY: 110.5,
        pixelCount: 2000,
      );

      final candidates = BlobFilter.filter([blob]);

      expect(candidates, isEmpty);
    });
  });
}
