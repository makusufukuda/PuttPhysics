import 'dart:math' as math;

import '../models/ball_candidate.dart';
import '../models/tracked_ball.dart';

class BallTracker {
  BallTracker({
    this.maximumMovementPixels = 120.0,
    this.maximumRadiusChangeRatio = 0.5,
    this.maximumMissedFrames = 3,
    this.movementStartThresholdPixels = 20.0,
  });

  final double maximumMovementPixels;
  final double maximumRadiusChangeRatio;
  final int maximumMissedFrames;
  final double movementStartThresholdPixels;

  TrackedBall? _previousTrackedBall;
  TrackedBall? _lastTrackedBall;

  int _missedFrameCount = 0;
  bool _movementStarted = false;
  bool _trackingEnded = false;

  int get missedFrameCount => _missedFrameCount;

  TrackedBall? get lastTrackedBall => _lastTrackedBall;

  void reset() {
    _previousTrackedBall = null;
    _lastTrackedBall = null;
    _missedFrameCount = 0;
    _movementStarted = false;
    _trackingEnded = false;
  }

  TrackedBall? track({
    required int frameIndex,
    required Duration timestamp,
    required List<BallCandidate> candidates,
  }) {
    if (_trackingEnded) {
      return null;
    }

    if (candidates.isEmpty) {
      _registerMiss();
      return null;
    }

    final selectedCandidate = _lastTrackedBall == null
        ? _selectInitialCandidate(candidates)
        : _findBestMatchingCandidate(candidates, timestamp);

    if (selectedCandidate == null) {
      _registerMiss();
      return null;
    }

    final previous = _lastTrackedBall;

    if (previous != null) {
      final dx = selectedCandidate.centerX - previous.centerX;
      final dy = selectedCandidate.centerY - previous.centerY;
      final distance = math.sqrt((dx * dx) + (dy * dy));

      if (distance >= movementStartThresholdPixels) {
        _movementStarted = true;
      }
    }

    final trackedBall = TrackedBall(
      frameIndex: frameIndex,
      timestamp: timestamp,
      centerX: selectedCandidate.centerX,
      centerY: selectedCandidate.centerY,
      radius: selectedCandidate.radius,
      confidence: selectedCandidate.confidence,
    );

    _previousTrackedBall = _lastTrackedBall;
    _lastTrackedBall = trackedBall;
    _missedFrameCount = 0;
    return trackedBall;
  }

  void _registerMiss() {
    _missedFrameCount++;

    if (_missedFrameCount > maximumMissedFrames) {
      _lastTrackedBall = null;

      if (_movementStarted) {
        _trackingEnded = true;
      }
    }
  }

  BallCandidate _selectInitialCandidate(List<BallCandidate> candidates) {
    for (final candidate in candidates) {
      if (candidate.isCombinedRedYellow) {
        return candidate;
      }
    }

    return candidates.first;
  }

  double _predictionScore(BallCandidate candidate, Duration timestamp) {
    final previous = _previousTrackedBall;
    final last = _lastTrackedBall;

    if (previous == null || last == null) {
      return 0.5;
    }

    final sampleTime =
        (last.timestamp - previous.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;

    final futureTime =
        (timestamp - last.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;

    if (sampleTime <= 0 || futureTime <= 0) {
      return 0.5;
    }

    final velocityX = (last.centerX - previous.centerX) / sampleTime;
    final velocityY = (last.centerY - previous.centerY) / sampleTime;

    final predictedX = last.centerX + (velocityX * futureTime);
    final predictedY = last.centerY + (velocityY * futureTime);

    final dx = candidate.centerX - predictedX;
    final dy = candidate.centerY - predictedY;
    final predictionDistance = math.sqrt((dx * dx) + (dy * dy));

    return (1.0 - (predictionDistance / maximumMovementPixels)).clamp(0.0, 1.0);
  }

  BallCandidate? _findBestMatchingCandidate(
    List<BallCandidate> candidates,
    Duration timestamp,
  ) {
    final previous = _lastTrackedBall;

    if (previous == null) {
      return candidates.first;
    }

    BallCandidate? bestCandidate;
    double? bestScore;
    BallCandidate? bestCombinedCandidate;
    double? bestCombinedScore;

    for (final candidate in candidates) {
      final dx = candidate.centerX - previous.centerX;
      final dy = candidate.centerY - previous.centerY;
      final distance = math.sqrt((dx * dx) + (dy * dy));

      if (distance > maximumMovementPixels) {
        continue;
      }

      final previousRadius = previous.radius;
      final radiusChangeRatio = previousRadius == 0
          ? 0.0
          : (candidate.radius - previousRadius).abs() / previousRadius;

      if (radiusChangeRatio > maximumRadiusChangeRatio) {
        continue;
      }

      final distanceScore = 1.0 - (distance / maximumMovementPixels);
      final predictionScore = _predictionScore(candidate, timestamp);
      final radiusScore = 1.0 - radiusChangeRatio;
      final confidenceScore = candidate.confidence;

      final score =
          (distanceScore * 0.4) +
          (predictionScore * 0.2) +
          (radiusScore * 0.15) +
          (confidenceScore * 0.25);

      if (bestScore == null || score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }

      if (candidate.isCombinedRedYellow &&
          (bestCombinedScore == null || score > bestCombinedScore)) {
        bestCombinedScore = score;
        bestCombinedCandidate = candidate;
      }
    }

    const combinedPreferenceTolerance = 0.05;

    if (bestCombinedCandidate != null &&
        bestCombinedScore != null &&
        bestScore != null &&
        bestCombinedScore >= bestScore - combinedPreferenceTolerance) {
      return bestCombinedCandidate;
    }

    return bestCandidate;
  }
}
