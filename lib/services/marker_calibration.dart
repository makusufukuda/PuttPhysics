import 'dart:math' as math;

import '../models/calibration_scale.dart';
import '../models/marker_calibration_result.dart';
import '../models/marker_candidate.dart';

class MarkerCalibration {
  const MarkerCalibration._();

  static const double horizontalMarkerDistanceMillimeters = 700.0;
  static const double verticalMarkerDistanceMillimeters = 237.0;

  static MarkerCalibrationResult? calculate(List<MarkerCandidate> markers) {
    if (markers.length != 4) {
      return null;
    }

    MarkerCandidate? find(MarkerPosition position) {
      for (final marker in markers) {
        if (marker.position == position) {
          return marker;
        }
      }

      return null;
    }

    final topLeft = find(MarkerPosition.topLeft);
    final topRight = find(MarkerPosition.topRight);
    final bottomLeft = find(MarkerPosition.bottomLeft);
    final bottomRight = find(MarkerPosition.bottomRight);

    if (topLeft == null ||
        topRight == null ||
        bottomLeft == null ||
        bottomRight == null) {
      return null;
    }

    final topDistancePixels = _distance(topLeft, topRight);
    final bottomDistancePixels = _distance(bottomLeft, bottomRight);
    final leftDistancePixels = _distance(topLeft, bottomLeft);
    final rightDistancePixels = _distance(topRight, bottomRight);

    if (topDistancePixels <= 0 ||
        bottomDistancePixels <= 0 ||
        leftDistancePixels <= 0 ||
        rightDistancePixels <= 0) {
      return null;
    }

    return MarkerCalibrationResult(
      topScale: CalibrationScale(
        referenceDistanceMillimeters: horizontalMarkerDistanceMillimeters,
        referenceDistancePixels: topDistancePixels,
      ),
      bottomScale: CalibrationScale(
        referenceDistanceMillimeters: horizontalMarkerDistanceMillimeters,
        referenceDistancePixels: bottomDistancePixels,
      ),
      topDistancePixels: topDistancePixels,
      bottomDistancePixels: bottomDistancePixels,
      leftDistancePixels: leftDistancePixels,
      rightDistancePixels: rightDistancePixels,
      topLeftX: topLeft.centerX,
      topLeftY: topLeft.centerY,
      topRightX: topRight.centerX,
      topRightY: topRight.centerY,
      bottomLeftX: bottomLeft.centerX,
      bottomLeftY: bottomLeft.centerY,
      bottomRightX: bottomRight.centerX,
      bottomRightY: bottomRight.centerY,
      topReferenceY: (topLeft.centerY + topRight.centerY) / 2.0,
      bottomReferenceY: (bottomLeft.centerY + bottomRight.centerY) / 2.0,
    );
  }

  static double _distance(MarkerCandidate first, MarkerCandidate second) {
    final dx = second.centerX - first.centerX;
    final dy = second.centerY - first.centerY;

    return math.sqrt((dx * dx) + (dy * dy));
  }
}
