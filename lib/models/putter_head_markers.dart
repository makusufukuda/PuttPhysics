import 'dart:math' as math;

class PutterHeadMarkers {
  const PutterHeadMarkers({
    required this.frameIndex,
    required this.timestamp,
    required this.markerAX,
    required this.markerAY,
    required this.markerBX,
    required this.markerBY,
  });

  final int frameIndex;
  final Duration timestamp;

  final double markerAX;
  final double markerAY;

  final double markerBX;
  final double markerBY;

  double get centerX => (markerAX + markerBX) / 2.0;
  double get centerY => (markerAY + markerBY) / 2.0;

  double get orientationDegrees {
    final deltaX = markerBX - markerAX;
    final deltaY = markerBY - markerAY;
    return math.atan2(deltaY, deltaX) * 180.0 / math.pi;
  }
}
