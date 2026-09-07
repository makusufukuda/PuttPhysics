import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/marker_candidate.dart';
import 'package:putt_physics_v1/services/marker_calibration.dart';

void main() {
  group('MarkerCalibration', () {
    test('calculates distances for 700 x 237 mm marker layout', () {
      const markers = [
        MarkerCandidate(
          position: MarkerPosition.topLeft,
          centerX: 100,
          centerY: 100,
          width: 20,
          height: 20,
          pixelCount: 300,
        ),
        MarkerCandidate(
          position: MarkerPosition.topRight,
          centerX: 800,
          centerY: 100,
          width: 20,
          height: 20,
          pixelCount: 300,
        ),
        MarkerCandidate(
          position: MarkerPosition.bottomLeft,
          centerX: 100,
          centerY: 337,
          width: 20,
          height: 20,
          pixelCount: 300,
        ),
        MarkerCandidate(
          position: MarkerPosition.bottomRight,
          centerX: 800,
          centerY: 337,
          width: 20,
          height: 20,
          pixelCount: 300,
        ),
      ];

      final result = MarkerCalibration.calculate(markers);

      expect(result, isNotNull);

      expect(result!.topDistancePixels, closeTo(700, 0.001));
      expect(result.bottomDistancePixels, closeTo(700, 0.001));

      expect(result.leftDistancePixels, closeTo(237, 0.001));
      expect(result.rightDistancePixels, closeTo(237, 0.001));

      expect(result.topScale.pixelsPerMillimeter, closeTo(1.0, 0.001));
      expect(result.bottomScale.pixelsPerMillimeter, closeTo(1.0, 0.001));
    });
  });
}
