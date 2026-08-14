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

    if (current.frameIndex != previous.frameIndex + 1) {
      return null;
    }

    return _calculateMetrics(previous: previous, current: current);
  }

  TrackingMetrics? latestSmoothedMetrics({int intervalCount = 3}) {
    if (intervalCount < 1 || _balls.length < intervalCount + 1) {
      return null;
    }

    final startIndex = _balls.length - intervalCount - 1;
    var totalDistance = 0.0;
    var totalTime = 0.0;

    for (var i = startIndex + 1; i < _balls.length; i++) {
      final previous = _balls[i - 1];
      final current = _balls[i];

      if (current.frameIndex != previous.frameIndex + 1) {
        return null;
      }

      final metrics = _calculateMetrics(previous: previous, current: current);

      if (metrics == null) {
        return null;
      }

      totalDistance += metrics.distancePixels;
      totalTime += metrics.deltaTimeSeconds;
    }

    if (totalTime <= 0) {
      return null;
    }

    return TrackingMetrics(
      deltaTimeSeconds: totalTime,
      distancePixels: totalDistance,
      speedPixelsPerSecond: totalDistance / totalTime,
    );
  }

  List<PeakTrackingMetrics> continuousMetrics() {
    final results = <PeakTrackingMetrics>[];

    for (var i = 1; i < _balls.length; i++) {
      final previous = _balls[i - 1];
      final current = _balls[i];

      if (current.frameIndex != previous.frameIndex + 1) {
        continue;
      }

      final metrics = _calculateMetrics(previous: previous, current: current);

      if (metrics == null) {
        continue;
      }

      results.add(
        PeakTrackingMetrics(
          previous: previous,
          current: current,
          metrics: metrics,
        ),
      );
    }

    return results;
  }

  PeakTrackingMetrics? smoothedPeakMetrics({int intervalCount = 3}) {
    if (intervalCount < 1 || _balls.length < intervalCount + 1) {
      return null;
    }

    PeakTrackingMetrics? peak;

    for (var endIndex = intervalCount; endIndex < _balls.length; endIndex++) {
      final startIndex = endIndex - intervalCount;

      var totalDistance = 0.0;
      var totalTime = 0.0;
      var validWindow = true;

      for (var i = startIndex + 1; i <= endIndex; i++) {
        final previous = _balls[i - 1];
        final current = _balls[i];

        if (current.frameIndex != previous.frameIndex + 1) {
          validWindow = false;
          break;
        }

        final metrics = _calculateMetrics(previous: previous, current: current);

        if (metrics == null) {
          validWindow = false;
          break;
        }

        totalDistance += metrics.distancePixels;
        totalTime += metrics.deltaTimeSeconds;
      }

      if (!validWindow || totalTime <= 0) {
        continue;
      }

      final metrics = TrackingMetrics(
        deltaTimeSeconds: totalTime,
        distancePixels: totalDistance,
        speedPixelsPerSecond: totalDistance / totalTime,
      );

      if (peak == null ||
          metrics.speedPixelsPerSecond > peak.metrics.speedPixelsPerSecond) {
        peak = PeakTrackingMetrics(
          previous: _balls[startIndex],
          current: _balls[endIndex],
          metrics: metrics,
        );
      }
    }

    return peak;
  }

  PeakTrackingMetrics? peakMetrics() {
    if (_balls.length < 2) {
      return null;
    }

    PeakTrackingMetrics? peak;

    for (var i = 1; i < _balls.length; i++) {
      final previous = _balls[i - 1];
      final current = _balls[i];

      if (current.frameIndex != previous.frameIndex + 1) {
        continue;
      }

      final metrics = _calculateMetrics(previous: previous, current: current);

      if (metrics == null) {
        continue;
      }

      if (peak == null ||
          metrics.speedPixelsPerSecond > peak.metrics.speedPixelsPerSecond) {
        peak = PeakTrackingMetrics(
          previous: previous,
          current: current,
          metrics: metrics,
        );
      }
    }

    return peak;
  }

  TrackingMetrics? _calculateMetrics({
    required TrackedBall previous,
    required TrackedBall current,
  }) {
    final dx = current.centerX - previous.centerX;
    final dy = current.centerY - previous.centerY;

    final distance = math.sqrt((dx * dx) + (dy * dy));

    final deltaTime =
        (current.timestamp - previous.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;

    if (deltaTime <= 0 || deltaTime > 1.0) {
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

class PeakTrackingMetrics {
  const PeakTrackingMetrics({
    required this.previous,
    required this.current,
    required this.metrics,
  });

  final TrackedBall previous;
  final TrackedBall current;
  final TrackingMetrics metrics;
}
