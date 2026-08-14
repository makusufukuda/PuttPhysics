import 'calibration_scale.dart';

class MarkerCalibrationResult {
  const MarkerCalibrationResult({
    required this.topScale,
    required this.bottomScale,
    required this.topDistancePixels,
    required this.bottomDistancePixels,
  });

  final CalibrationScale topScale;
  final CalibrationScale bottomScale;

  final double topDistancePixels;
  final double bottomDistancePixels;

  double get averagePixelsPerMillimeter =>
      (topScale.pixelsPerMillimeter + bottomScale.pixelsPerMillimeter) / 2.0;

  double get scaleDifferenceRatio {
    final average = averagePixelsPerMillimeter;

    if (average <= 0) {
      return 0;
    }

    return (topScale.pixelsPerMillimeter - bottomScale.pixelsPerMillimeter)
            .abs() /
        average;
  }
}
