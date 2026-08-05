import 'dart:math' as math;

import '../models/ball_candidate.dart';
import '../models/tracked_ball.dart';

class BallTracker {
  BallTracker({
    this.maximumMovementPixels = 120.0,
    this.maximumRadiusChangeRatio = 0.5,
  });

  final double maximumMovementPixels;
  final double maximumRadiusChangeRatio;

  TrackedBall? _lastTrackedBall;

  TrackedBall? get lastTrackedBall => _lastTrackedBall;

  void reset() {
    _lastTrackedBall = null;
  }

  TrackedBall? track({
    required int frameIndex,
    required Duration timestamp,
    required List<BallCandidate> candidates,
  }) {
    if (candidates.isEmpty) {
      return null;
    }

    final selectedCandidate = _lastTrackedBall == null
        ? candidates.first
        : _findBestMatchingCandidate(candidates);

    if (selectedCandidate == null) {
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
