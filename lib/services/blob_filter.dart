import 'dart:math' as math;

import '../models/ball_candidate.dart';
import '../models/blob.dart';

class BlobFilter {
  const BlobFilter._();

  static const int minimumPixelCount = 50;
  static const int minimumDiameter = 8;
  static const int maximumDiameter = 300;

  static const double minimumAspectRatio = 0.65;
  static const double maximumAspectRatio = 1.35;
  static const double minimumFillRatio = 0.45;

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
    if (!_passesSizeCondition(blob)) {
      return null;
    }

    final aspectRatio = blob.width / blob.height;

    if (aspectRatio < minimumAspectRatio || aspectRatio > maximumAspectRatio) {
      return null;
    }

    if (blob.fillRatio < minimumFillRatio) {
      return null;
    }

    final estimatedRadius = (blob.width + blob.height) / 4.0;

    final confidence = _calculateConfidence(
      blob: blob,
      aspectRatio: aspectRatio,
    );

    return BallCandidate(
      centerX: blob.centroidX,
      centerY: blob.centroidY,
      radius: estimatedRadius,
      confidence: confidence,
    );
  }

  static bool _passesSizeCondition(Blob blob) {
    if (blob.pixelCount < minimumPixelCount) {
      return false;
    }

    if (blob.width < minimumDiameter || blob.height < minimumDiameter) {
      return false;
    }

    if (blob.width > maximumDiameter || blob.height > maximumDiameter) {
      return false;
    }

    return true;
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
