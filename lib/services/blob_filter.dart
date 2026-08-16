import 'dart:math' as math;

import '../models/ball_candidate.dart';
import '../models/blob.dart';

class BlobFilter {
  const BlobFilter._();

  static const int minimumPixelCount = 50;
  static const int minimumDiameter = 30;
  static const int maximumDiameter = 300;

  static const double minimumAspectRatio = 0.65;
  static const double maximumAspectRatio = 1.60;
  static const double minimumFillRatio = 0.40;

  // A fast-moving ball can become horizontally elongated because of
  // motion blur. Keep this separate from the normal round-ball limits.
  static const int minimumMotionBlurHeight = 12;
  static const int maximumMotionBlurHeight = 40;
  static const int minimumMotionBlurWidth = 40;
  static const int maximumMotionBlurWidth = 160;
  static const double minimumMotionBlurAspectRatio = 1.60;
  static const double maximumMotionBlurAspectRatio = 7.00;
  static const double minimumMotionBlurFillRatio = 0.35;

  static List<BallCandidate> filter(List<Blob> blobs) {
    final candidates = <BallCandidate>[];

    for (final blob in blobs) {
      final candidate = _createBallCandidate(blob);

      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    return candidates;
  }

  static BallCandidate? _createBallCandidate(Blob blob) {
    if (blob.pixelCount < minimumPixelCount) {
      return null;
    }

    final hasNormalSize =
        blob.width >= minimumDiameter && blob.height >= minimumDiameter;

    final hasMotionBlurSize =
        blob.width >= minimumMotionBlurWidth &&
        blob.width <= maximumMotionBlurWidth &&
        blob.height >= minimumMotionBlurHeight &&
        blob.height <= maximumMotionBlurHeight;

    if (!hasNormalSize && !hasMotionBlurSize) {
      return null;
    }

    if (blob.width > maximumDiameter || blob.height > maximumDiameter) {
      return null;
    }

    final aspectRatio = blob.width / blob.height;

    final isNormalBall =
        aspectRatio >= minimumAspectRatio &&
        aspectRatio <= maximumAspectRatio &&
        blob.fillRatio >= minimumFillRatio;

    final isMotionBlur =
        blob.width >= minimumMotionBlurWidth &&
        blob.width <= maximumMotionBlurWidth &&
        blob.height >= minimumMotionBlurHeight &&
        blob.height <= maximumMotionBlurHeight &&
        aspectRatio > minimumMotionBlurAspectRatio &&
        aspectRatio <= maximumMotionBlurAspectRatio &&
        blob.fillRatio >= minimumMotionBlurFillRatio;

    if (!isNormalBall && !isMotionBlur) {
      return null;
    }

    final estimatedRadius = isMotionBlur
        ? blob.height / 2.0
        : (blob.width + blob.height) / 4.0;

    final confidence = isMotionBlur
        ? _calculateMotionBlurConfidence(blob: blob, aspectRatio: aspectRatio)
        : _calculateConfidence(blob: blob, aspectRatio: aspectRatio);

    final centerX = (blob.minX + blob.maxX) / 2.0;
    final centerY = (blob.minY + blob.maxY) / 2.0;

    return BallCandidate(
      centerX: centerX,
      centerY: centerY,
      radius: estimatedRadius,
      confidence: confidence,
      isMotionBlur: isMotionBlur,
    );
  }

  static double _calculateMotionBlurConfidence({
    required Blob blob,
    required double aspectRatio,
  }) {
    final fillScore = blob.fillRatio.clamp(0.0, 1.0);

    // Motion-blurred candidates are intentionally scored conservatively.
    // BallTracker will later use position and motion prediction to decide
    // whether the candidate should actually be tracked.
    final aspectScore =
        (1.0 -
                ((aspectRatio - minimumMotionBlurAspectRatio) /
                    (maximumMotionBlurAspectRatio -
                        minimumMotionBlurAspectRatio)))
            .clamp(0.0, 1.0);

    final score = (fillScore * 0.6) + (aspectScore * 0.4);

    return math.max(0.0, math.min(1.0, score));
  }

  static double _calculateConfidence({
    required Blob blob,
    required double aspectRatio,
  }) {
    final aspectScore = 1.0 - (aspectRatio - 1.0).abs();
    final fillScore = blob.fillRatio.clamp(0.0, 1.0);

    final score = (aspectScore * 0.6) + (fillScore * 0.4);

    return math.max(0.0, math.min(1.0, score));
  }
}
