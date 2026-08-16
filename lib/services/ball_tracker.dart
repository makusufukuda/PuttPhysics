import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/ball_candidate.dart';
import '../models/tracked_ball.dart';

class BallTracker {
  BallTracker({
    this.maximumMovementPixels = 120.0,
    this.maximumMotionBlurMovementPixels = 300.0,
    this.maximumPredictedMovementPixels = 160.0,
    this.minimumPredictionScoreForExtendedMovement = 0.70,
    this.directionPreferenceThresholdPixels = 60.0,
    this.maximumRadiusChangeRatio = 0.5,
    this.maximumMissedFrames = 3,
    this.movementStartThresholdPixels = 20.0,
  });

  final double maximumMovementPixels;
  final double maximumMotionBlurMovementPixels;
  final double maximumPredictedMovementPixels;
  final double minimumPredictionScoreForExtendedMovement;
  final double directionPreferenceThresholdPixels;
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
        : _findBestMatchingCandidate(candidates, timestamp, frameIndex);

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

  double _predictionScore(
    BallCandidate candidate,
    Duration timestamp, {
    int? frameIndex,
  }) {
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

    final predictionScore = (1.0 - (predictionDistance / maximumMovementPixels))
        .clamp(0.0, 1.0);

    if (frameIndex != null) {
      debugPrint(
        'TRACKER PREDICTION '
        'frame=$frameIndex '
        'previousFrame=${previous.frameIndex} '
        'lastFrame=${last.frameIndex} '
        'previousX=${previous.centerX.toStringAsFixed(1)} '
        'previousY=${previous.centerY.toStringAsFixed(1)} '
        'lastX=${last.centerX.toStringAsFixed(1)} '
        'lastY=${last.centerY.toStringAsFixed(1)} '
        'sampleTime=${sampleTime.toStringAsFixed(4)} '
        'futureTime=${futureTime.toStringAsFixed(4)} '
        'velocityX=${velocityX.toStringAsFixed(1)} '
        'velocityY=${velocityY.toStringAsFixed(1)} '
        'predictedX=${predictedX.toStringAsFixed(1)} '
        'predictedY=${predictedY.toStringAsFixed(1)} '
        'candidateX=${candidate.centerX.toStringAsFixed(1)} '
        'candidateY=${candidate.centerY.toStringAsFixed(1)} '
        'error=${predictionDistance.toStringAsFixed(1)} '
        'score=${predictionScore.toStringAsFixed(3)}',
      );
    }

    return predictionScore;
  }

  BallCandidate? _findBestMatchingCandidate(
    List<BallCandidate> candidates,
    Duration timestamp,
    int frameIndex,
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

      final predictionScore = _predictionScore(
        candidate,
        timestamp,
        frameIndex: frameIndex,
      );

      var movementLimit = candidate.isMotionBlur
          ? maximumMotionBlurMovementPixels
          : maximumMovementPixels;

      final previousTracked = _previousTrackedBall;
      final lastTracked = _lastTrackedBall;

      var sameDirection = false;

      if (previousTracked != null && lastTracked != null) {
        final previousDx = lastTracked.centerX - previousTracked.centerX;
        final previousDy = lastTracked.centerY - previousTracked.centerY;

        final candidateDx = candidate.centerX - lastTracked.centerX;
        final candidateDy = candidate.centerY - lastTracked.centerY;

        final directionDot =
            (previousDx * candidateDx) + (previousDy * candidateDy);

        sameDirection = directionDot > 0;
      }

      final canUsePredictedMovementLimit =
          !candidate.isMotionBlur &&
          predictionScore >= minimumPredictionScoreForExtendedMovement;

      final canUseDirectionalMovementLimit =
          !candidate.isMotionBlur && _movementStarted && sameDirection;

      if ((canUsePredictedMovementLimit || canUseDirectionalMovementLimit) &&
          maximumPredictedMovementPixels > movementLimit) {
        movementLimit = maximumPredictedMovementPixels;
      }

      if (distance > movementLimit) {
        debugPrint(
          'TRACKER REJECT '
          'frame=$frameIndex '
          'reason=movement '
          'candidateX=${candidate.centerX.toStringAsFixed(1)} '
          'candidateY=${candidate.centerY.toStringAsFixed(1)} '
          'distance=${distance.toStringAsFixed(1)} '
          'max=${movementLimit.toStringAsFixed(1)} '
          'prediction=${predictionScore.toStringAsFixed(3)} '
          'sameDirection=$sameDirection '
          'radius=${candidate.radius.toStringAsFixed(1)} '
          'motionBlur=${candidate.isMotionBlur}',
        );
        continue;
      }

      final previousRadius = previous.radius;
      final radiusChangeRatio = previousRadius == 0
          ? 0.0
          : (candidate.radius - previousRadius).abs() / previousRadius;

      if (radiusChangeRatio > maximumRadiusChangeRatio) {
        debugPrint(
          'TRACKER REJECT '
          'frame=$frameIndex '
          'reason=radius '
          'candidateX=${candidate.centerX.toStringAsFixed(1)} '
          'candidateY=${candidate.centerY.toStringAsFixed(1)} '
          'distance=${distance.toStringAsFixed(1)} '
          'previousRadius=${previousRadius.toStringAsFixed(1)} '
          'candidateRadius=${candidate.radius.toStringAsFixed(1)} '
          'radiusChange=${radiusChangeRatio.toStringAsFixed(3)} '
          'max=${maximumRadiusChangeRatio.toStringAsFixed(3)} '
          'motionBlur=${candidate.isMotionBlur}',
        );
        continue;
      }

      final distanceScore = 1.0 - (distance / movementLimit);
      final radiusScore = 1.0 - radiusChangeRatio;
      final confidenceScore = candidate.confidence;

      var directionPreferenceActive = false;

      if (previousTracked != null && lastTracked != null) {
        final previousDx = lastTracked.centerX - previousTracked.centerX;
        final previousDy = lastTracked.centerY - previousTracked.centerY;
        final previousMovement = math.sqrt(
          (previousDx * previousDx) + (previousDy * previousDy),
        );

        directionPreferenceActive =
            previousMovement >= directionPreferenceThresholdPixels;
      }

      final score = directionPreferenceActive
          ? (distanceScore * 0.20) +
                (predictionScore * 0.45) +
                (radiusScore * 0.10) +
                (confidenceScore * 0.25)
          : (distanceScore * 0.40) +
                (predictionScore * 0.20) +
                (radiusScore * 0.15) +
                (confidenceScore * 0.25);

      debugPrint(
        'TRACKER CANDIDATE '
        'frame=$frameIndex '
        'x=${candidate.centerX.toStringAsFixed(1)} '
        'y=${candidate.centerY.toStringAsFixed(1)} '
        'distance=${distance.toStringAsFixed(1)} '
        'radius=${candidate.radius.toStringAsFixed(1)} '
        'radiusChange=${radiusChangeRatio.toStringAsFixed(3)} '
        'confidence=${candidate.confidence.toStringAsFixed(3)} '
        'prediction=${predictionScore.toStringAsFixed(3)} '
        'score=${score.toStringAsFixed(3)} '
        'directionPreference=$directionPreferenceActive '
        'sameDirection=$sameDirection '
        'combined=${candidate.isCombinedRedYellow} '
        'motionBlur=${candidate.isMotionBlur}',
      );

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
      debugPrint(
        'TRACKER SELECT '
        'frame=$frameIndex '
        'type=combined '
        'x=${bestCombinedCandidate.centerX.toStringAsFixed(1)} '
        'y=${bestCombinedCandidate.centerY.toStringAsFixed(1)} '
        'score=${bestCombinedScore.toStringAsFixed(3)}',
      );
      return bestCombinedCandidate;
    }

    if (bestCandidate != null && bestScore != null) {
      debugPrint(
        'TRACKER SELECT '
        'frame=$frameIndex '
        'type=${bestCandidate.isMotionBlur ? 'motionBlur' : 'normal'} '
        'x=${bestCandidate.centerX.toStringAsFixed(1)} '
        'y=${bestCandidate.centerY.toStringAsFixed(1)} '
        'score=${bestScore.toStringAsFixed(3)}',
      );
    } else {
      debugPrint(
        'TRACKER NO MATCH '
        'frame=$frameIndex '
        'previousX=${previous.centerX.toStringAsFixed(1)} '
        'previousY=${previous.centerY.toStringAsFixed(1)} '
        'previousRadius=${previous.radius.toStringAsFixed(1)} '
        'candidateCount=${candidates.length}',
      );
    }

    return bestCandidate;
  }
}
