import 'dart:math' as math;

import '../models/marker_calibration_result.dart';
import '../models/tracked_ball.dart';
import '../models/tracking_session.dart';
import 'perspective_calibration.dart';

class RealSpeedResult {
  const RealSpeedResult({
    required this.middleY,
    required this.pixelsPerMillimeter,
    required this.distanceMillimeters,
    required this.speedMillimetersPerSecond,
    required this.speedMetersPerSecond,
  });

  final double middleY;

  // Kept for diagnostics and compatibility with the existing log output.
  final double pixelsPerMillimeter;

  final double distanceMillimeters;
  final double speedMillimetersPerSecond;
  final double speedMetersPerSecond;
}

class RealSpeedCalculator {
  const RealSpeedCalculator._();

  static RealSpeedResult? calculate({
    required MarkerCalibrationResult calibration,
    required TrackedBall previous,
    required TrackedBall current,
    required TrackingMetrics metrics,
  }) {
    if (metrics.deltaTimeSeconds <= 0) {
      return null;
    }

    final previousWorld = PerspectiveCalibration.imageToMillimeters(
      calibration: calibration,
      x: previous.centerX,
      y: previous.centerY,
    );

    final currentWorld = PerspectiveCalibration.imageToMillimeters(
      calibration: calibration,
      x: current.centerX,
      y: current.centerY,
    );

    if (previousWorld == null || currentWorld == null) {
      return null;
    }

    final deltaX = currentWorld.xMillimeters - previousWorld.xMillimeters;
    final deltaY = currentWorld.yMillimeters - previousWorld.yMillimeters;

    final distanceMillimeters = math.sqrt(
      (deltaX * deltaX) + (deltaY * deltaY),
    );

    final speedMillimetersPerSecond =
        distanceMillimeters / metrics.deltaTimeSeconds;

    final speedMetersPerSecond = speedMillimetersPerSecond / 1000.0;

    final middleY = (previous.centerY + current.centerY) / 2.0;

    final pixelsPerMillimeter = calibration.pixelsPerMillimeterAtY(middleY);

    return RealSpeedResult(
      middleY: middleY,
      pixelsPerMillimeter: pixelsPerMillimeter,
      distanceMillimeters: distanceMillimeters,
      speedMillimetersPerSecond: speedMillimetersPerSecond,
      speedMetersPerSecond: speedMetersPerSecond,
    );
  }
}
