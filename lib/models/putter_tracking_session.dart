import 'dart:math' as math;

import 'tracked_putter.dart';

class PutterTrackingSession {
  final List<TrackedPutter> _putters = [];

  List<TrackedPutter> get putters => List.unmodifiable(_putters);

  int get length => _putters.length;

  void add(TrackedPutter putter) {
    if (_putters.isNotEmpty &&
        putter.timestamp <= _putters.last.timestamp) {
      return;
    }

    _putters.add(putter);
  }

  void clear() {
    _putters.clear();
  }

  PutterSpeedMetrics? latestMetrics() {
    if (_putters.length < 2) {
      return null;
    }

    final previous = _putters[_putters.length - 2];
    final current = _putters.last;

    if (current.frameIndex != previous.frameIndex + 1) {
      return null;
    }

    final deltaTime =
        (current.timestamp - previous.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;

    if (deltaTime <= 0 || deltaTime > 1.0) {
      return null;
    }

    final dx = current.centerX - previous.centerX;
    final dy = current.centerY - previous.centerY;
    final distance = math.sqrt(dx * dx + dy * dy);

    return PutterSpeedMetrics(
      distancePixels: distance,
      deltaTimeSeconds: deltaTime,
      speedPixelsPerSecond: distance / deltaTime,
    );
  }
}

class PutterSpeedMetrics {
  const PutterSpeedMetrics({
    required this.distancePixels,
    required this.deltaTimeSeconds,
    required this.speedPixelsPerSecond,
  });

  final double distancePixels;
  final double deltaTimeSeconds;
  final double speedPixelsPerSecond;
}
