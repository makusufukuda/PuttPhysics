import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/calibration_scale.dart';
import 'package:putt_physics_v1/models/marker_calibration_result.dart';
import 'package:putt_physics_v1/models/tracked_ball.dart';
import 'package:putt_physics_v1/models/tracking_session.dart';
import 'package:putt_physics_v1/services/real_speed_calculator.dart';

void main() {
  group('RealSpeedCalculator', () {
    test('calculates real speed from perspective-corrected coordinates', () {
      const calibration = MarkerCalibrationResult(
        topScale: CalibrationScale(
          referenceDistanceMillimeters: 700,
          referenceDistancePixels: 700,
        ),
        bottomScale: CalibrationScale(
          referenceDistanceMillimeters: 700,
          referenceDistancePixels: 700,
        ),
        topDistancePixels: 700,
        bottomDistancePixels: 700,
        leftDistancePixels: 237,
        rightDistancePixels: 237,
        topLeftX: 0,
        topLeftY: 0,
        topRightX: 700,
        topRightY: 0,
        bottomLeftX: 0,
        bottomLeftY: 237,
        bottomRightX: 700,
        bottomRightY: 237,
        topReferenceY: 0,
        bottomReferenceY: 237,
      );

      const previous = TrackedBall(
        frameIndex: 1,
        timestamp: Duration(milliseconds: 0),
        centerX: 100,
        centerY: 100,
        radius: 10,
        confidence: 1,
      );

      const current = TrackedBall(
        frameIndex: 2,
        timestamp: Duration(milliseconds: 100),
        centerX: 200,
        centerY: 100,
        radius: 10,
        confidence: 1,
      );

      const metrics = TrackingMetrics(
        deltaTimeSeconds: 0.1,
        distancePixels: 100,
        speedPixelsPerSecond: 1000,
      );

      final result = RealSpeedCalculator.calculate(
        calibration: calibration,
        previous: previous,
        current: current,
        metrics: metrics,
      );

      expect(result, isNotNull);
      expect(result!.distanceMillimeters, closeTo(100, 0.001));
      expect(result.speedMillimetersPerSecond, closeTo(1000, 0.001));
      expect(result.speedMetersPerSecond, closeTo(1.0, 0.001));
    });

    test('corrects perspective before calculating real speed', () {
      const calibration = MarkerCalibrationResult(
        topScale: CalibrationScale(
          referenceDistanceMillimeters: 700,
          referenceDistancePixels: 500,
        ),
        bottomScale: CalibrationScale(
          referenceDistanceMillimeters: 700,
          referenceDistancePixels: 600,
        ),
        topDistancePixels: 500,
        bottomDistancePixels: 600,
        leftDistancePixels: 130,
        rightDistancePixels: 130,
        topLeftX: 100,
        topLeftY: 800,
        topRightX: 600,
        topRightY: 820,
        bottomLeftX: 40,
        bottomLeftY: 920,
        bottomRightX: 640,
        bottomRightY: 940,
        topReferenceY: 810,
        bottomReferenceY: 930,
      );

      const previous = TrackedBall(
        frameIndex: 1,
        timestamp: Duration(milliseconds: 0),
        centerX: 100,
        centerY: 800,
        radius: 10,
        confidence: 1,
      );

      const current = TrackedBall(
        frameIndex: 2,
        timestamp: Duration(milliseconds: 100),
        centerX: 600,
        centerY: 820,
        radius: 10,
        confidence: 1,
      );

      const metrics = TrackingMetrics(
        deltaTimeSeconds: 0.1,
        distancePixels: 500.4,
        speedPixelsPerSecond: 5004,
      );

      final result = RealSpeedCalculator.calculate(
        calibration: calibration,
        previous: previous,
        current: current,
        metrics: metrics,
      );

      expect(result, isNotNull);

      // The two image points are the real-world top-left and top-right
      // calibration markers, so their corrected distance must be 700 mm.
      expect(result!.distanceMillimeters, closeTo(700, 0.001));
      expect(result.speedMillimetersPerSecond, closeTo(7000, 0.001));
      expect(result.speedMetersPerSecond, closeTo(7.0, 0.001));
    });
  });
}
