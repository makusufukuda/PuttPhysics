import 'dart:math' as math;

import '../models/ball_candidate.dart';
import '../models/tracked_ball.dart';

class BallTracker {
  BallTracker({
    this.maximumMovementPixels = 120.0,
    this.maximumRadiusChangeRatio = 0.5,
    this.maximumMissedFrames = 3,
  });

  final double maximumMovementPixels;
  final double maximumRadiusChangeRatio;
  final int maximumMissedFrames;

  TrackedBall? _lastTrackedBall;

  int _missedFrameCount = 0;

  int get missedFrameCount => _missedFrameCount;

  TrackedBall? get lastTrackedBall => _lastTrackedBall;

  void reset() {
    _lastTrackedBall = null;
    _missedFrameCount = 0;
  }

  TrackedBall? track({
    required int frameIndex,
    required Duration timestamp,
    required List<BallCandidate> candidates,
  }) {
    if (candidates.isEmpty) {
      _missedFrameCount++;

      if (_missedFrameCount > maximumMissedFrames) {
        _lastTrackedBall = null;
      }

      return null;
    }

    final selectedCandidate = _lastTrackedBall == null
        ? candidates.first
        : _findBestMatchingCandidate(candidates);

    if (selectedCandidate == null) {
      _missedFrameCount++;

      if (_missedFrameCount > maximumMissedFrames) {
        _lastTrackedBall = null;
      }

      return null;
    }

    final trackedBall = TrackedBall(
      frameIndex: frameIndex,
      timestamp: timestamp,
      centerX: selectedCandidate.centerX,
      centerY: selectedCandidate.centerY,
      radius: selectedCandidate.radius,
      confidence: selectedCandidate.confidence,
    );

    _lastTrackedBall = trackedBall;
    _missedFrameCount = 0;
    return trackedBall;
  }

  BallCandidate? _findBestMatchingCandidate(List<BallCandidate> candidates) {
    final previous = _lastTrackedBall;

    if (previous == null) {
      return candidates.first;
    }

    BallCandidate? bestCandidate;
    double? bestScore;

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
      final radiusScore = 1.0 - radiusChangeRatio;
      final confidenceScore = candidate.confidence;

      final score =
          (distanceScore * 0.5) + (radiusScore * 0.2) + (confidenceScore * 0.3);

      if (bestScore == null || score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    return bestCandidate;
  }
}
