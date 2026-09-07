import 'calibration_scale.dart';

class MarkerCalibrationResult {
  const MarkerCalibrationResult({
    required this.topScale,
    required this.bottomScale,
    required this.topDistancePixels,
    required this.bottomDistancePixels,
    required this.leftDistancePixels,
    required this.rightDistancePixels,
    required this.topLeftX,
    required this.topLeftY,
    required this.topRightX,
    required this.topRightY,
    required this.bottomLeftX,
    required this.bottomLeftY,
    required this.bottomRightX,
    required this.bottomRightY,
    required this.topReferenceY,
    required this.bottomReferenceY,
  });

  final CalibrationScale topScale;
  final CalibrationScale bottomScale;

  final double topDistancePixels;
  final double bottomDistancePixels;
  final double leftDistancePixels;
  final double rightDistancePixels;

  final double topLeftX;
  final double topLeftY;
  final double topRightX;
  final double topRightY;
  final double bottomLeftX;
  final double bottomLeftY;
  final double bottomRightX;
  final double bottomRightY;

  final double topReferenceY;
  final double bottomReferenceY;

  double get averagePixelsPerMillimeter =>
      (topScale.pixelsPerMillimeter + bottomScale.pixelsPerMillimeter) / 2.0;

  double pixelsPerMillimeterAtY(double y) {
    final yRange = bottomReferenceY - topReferenceY;

    if (yRange.abs() < 0.000001) {
      return averagePixelsPerMillimeter;
    }

    final interpolation = ((y - topReferenceY) / yRange).clamp(0.0, 1.0);

    return topScale.pixelsPerMillimeter +
        ((bottomScale.pixelsPerMillimeter - topScale.pixelsPerMillimeter) *
            interpolation);
  }

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
