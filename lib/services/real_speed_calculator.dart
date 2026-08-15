import '../models/marker_calibration_result.dart';
import '../models/tracked_ball.dart';
import '../models/tracking_session.dart';

class RealSpeedResult {
  const RealSpeedResult({
    required this.middleY,
    required this.pixelsPerMillimeter,
    required this.speedMillimetersPerSecond,
    required this.speedMetersPerSecond,
  });

  final double middleY;
  final double pixelsPerMillimeter;
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
    final middleY = (previous.centerY + current.centerY) / 2.0;

    final pixelsPerMillimeter = calibration.pixelsPerMillimeterAtY(middleY);

    if (pixelsPerMillimeter <= 0) {
      return null;
    }

    final speedMillimetersPerSecond =
        metrics.speedPixelsPerSecond / pixelsPerMillimeter;

    final speedMetersPerSecond = speedMillimetersPerSecond / 1000.0;

    return RealSpeedResult(
      middleY: middleY,
      pixelsPerMillimeter: pixelsPerMillimeter,
      speedMillimetersPerSecond: speedMillimetersPerSecond,
      speedMetersPerSecond: speedMetersPerSecond,
    );
  }
}
