import 'dart:math' as math;

import 'tracked_ball.dart';

class TrackingSession {
  final List<TrackedBall> _balls = [];

  List<TrackedBall> get balls => List.unmodifiable(_balls);

  int get length => _balls.length;

  bool get isEmpty => _balls.isEmpty;

  bool get isNotEmpty => _balls.isNotEmpty;

  TrackedBall? get first => _balls.isEmpty ? null : _balls.first;

  TrackedBall? get latest => _balls.isEmpty ? null : _balls.last;

  void add(TrackedBall ball) {
    final latestBall = latest;

    if (latestBall != null && ball.timestamp <= latestBall.timestamp) {
      return;
    }

    _balls.add(ball);
  }

  void clear() {
    _balls.clear();
  }

  TrackingMetrics? latestMetrics() {
    if (_balls.length < 2) {
      return null;
    }

    final previous = _balls[_balls.length - 2];
    final current = _balls.last;

    final dx = current.centerX - previous.centerX;
    final dy = current.centerY - previous.centerY;

    final distance = math.sqrt((dx * dx) + (dy * dy));

    final deltaTime =
        (current.timestamp - previous.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;

    if (deltaTime <= 0) {
      return null;
    }

    return TrackingMetrics(
      deltaTimeSeconds: deltaTime,
      distancePixels: distance,
      speedPixelsPerSecond: distance / deltaTime,
    );
  }
}

class TrackingMetrics {
  const TrackingMetrics({
    required this.deltaTimeSeconds,
    required this.distancePixels,
    required this.speedPixelsPerSecond,
  });

  final double deltaTimeSeconds;
  final double distancePixels;
  final double speedPixelsPerSecond;
}
