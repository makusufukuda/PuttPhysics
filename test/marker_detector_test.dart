import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/blob.dart';
import 'package:putt_physics_v1/services/marker_detector.dart';

void main() {
  group('MarkerDetector', () {
    test('selects four calibration blobs with strong perspective', () {
      const blobs = [
        // Far/top calibration markers observed with the current
        // rear-camera setup.
        Blob(
          pixelCount: 24,
          minX: 206,
          minY: 522,
          maxX: 211,
          maxY: 527,
          centroidX: 208.8,
          centroidY: 524.5,
        ),
        Blob(
          pixelCount: 27,
          minX: 177,
          minY: 528,
          maxX: 182,
          maxY: 533,
          centroidX: 179.6,
          centroidY: 530.7,
        ),

        // Near/bottom calibration markers.
        Blob(
          pixelCount: 2490,
          minX: 479,
          minY: 993,
          maxX: 558,
          maxY: 1044,
          centroidX: 518.6,
          centroidY: 1018.2,
        ),
        Blob(
          pixelCount: 1217,
          minX: 86,
          minY: 1003,
          maxX: 145,
          maxY: 1051,
          centroidX: 115.4,
          centroidY: 1027.3,
        ),

        // Extra component observed inside/near a physical marker.
        Blob(
          pixelCount: 194,
          minX: 510,
          minY: 1012,
          maxX: 527,
          maxY: 1023,
          centroidX: 518.5,
          centroidY: 1017.5,
        ),

        // Extra component observed inside the near-left physical marker.
        Blob(
          pixelCount: 44,
          minX: 99,
          minY: 1023,
          maxX: 106,
          maxY: 1030,
          centroidX: 102.4,
          centroidY: 1026.8,
        ),
      ];

      final selected = MarkerDetector.selectBestFourMarkerBlobsForTesting(
        blobs,
      );

      expect(selected, isNotNull);
      expect(selected, hasLength(4));

      final centers = selected!
          .map((blob) => (blob.centroidX.round(), blob.centroidY.round()))
          .toSet();

      expect(centers, contains((209, 525)));
      expect(centers, contains((180, 531)));
      expect(centers, contains((519, 1018)));
      expect(centers, contains((115, 1027)));
    });
  });
}
