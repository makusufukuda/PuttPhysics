import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/calibration_scale.dart';
import 'package:putt_physics_v1/models/marker_calibration_result.dart';
import 'package:putt_physics_v1/models/tracked_ball.dart';
import 'package:putt_physics_v1/models/tracking_session.dart';
import 'package:putt_physics_v1/services/real_speed_calculator.dart';

void main() {
  group('RealSpeedCalculator', () {
    test('converts pixels per second to meters per second', () {
      const calibration = MarkerCalibrationResult(
        topScale: CalibrationScale(
          referenceDistanceMillimeters: 1000,
          referenceDistancePixels: 2000,
        ),
        bottomScale: CalibrationScale(
          referenceDistanceMillimeters: 1000,
          referenceDistancePixels: 2000,
        ),
        topDistancePixels: 2000,
        bottomDistancePixels: 2000,
        topReferenceY: 0,
        bottomReferenceY: 1000,
      );

      const previous = TrackedBall(
        frameIndex: 1,
        timestamp: Duration(milliseconds: 0),
        centerX: 0,
        centerY: 500,
        radius: 10,
        confidence: 1,
      );

      const current = TrackedBall(
        frameIndex: 2,
        timestamp: Duration(milliseconds: 50),
        centerX: 50,
        centerY: 500,
        radius: 10,
        confidence: 1,
      );

      const metrics = TrackingMetrics(
        deltaTimeSeconds: 0.05,
        distancePixels: 50,
        speedPixelsPerSecond: 1000,
      );

      final result = RealSpeedCalculator.calculate(
        calibration: calibration,
        previous: previous,
        current: current,
        metrics: metrics,
      );

      expect(result, isNotNull);
      expect(result!.middleY, 500);
      expect(result.pixelsPerMillimeter, 2.0);
      expect(result.speedMillimetersPerSecond, 500.0);
      expect(result.speedMetersPerSecond, 0.5);
    });

    test('uses interpolated scale at middle Y', () {
      const calibration = MarkerCalibrationResult(
        topScale: CalibrationScale(
          referenceDistanceMillimeters: 1000,
          referenceDistancePixels: 1000,
        ),
        bottomScale: CalibrationScale(
          referenceDistanceMillimeters: 1000,
          referenceDistancePixels: 2000,
        ),
        topDistancePixels: 1000,
        bottomDistancePixels: 2000,
        topReferenceY: 100,
        bottomReferenceY: 300,
      );

      const previous = TrackedBall(
        frameIndex: 1,
        timestamp: Duration(milliseconds: 0),
        centerX: 0,
        centerY: 150,
        radius: 10,
        confidence: 1,
      );

      const current = TrackedBall(
        frameIndex: 2,
        timestamp: Duration(milliseconds: 50),
        centerX: 75,
        centerY: 250,
        radius: 10,
        confidence: 1,
      );

      const metrics = TrackingMetrics(
        deltaTimeSeconds: 0.05,
        distancePixels: 75,
        speedPixelsPerSecond: 1500,
      );

      final result = RealSpeedCalculator.calculate(
        calibration: calibration,
        previous: previous,
        current: current,
        metrics: metrics,
      );

      expect(result, isNotNull);
      expect(result!.middleY, 200);
      expect(result.pixelsPerMillimeter, 1.5);
      expect(result.speedMillimetersPerSecond, 1000.0);
      expect(result.speedMetersPerSecond, 1.0);
    });
  });
}
