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

  static List<BallCandidate> filter(List<Blob> blobs) {
    final candidates = <BallCandidate>[];

    print('===== BlobFilter start: ${blobs.length} blobs =====');

    for (var i = 0; i < blobs.length; i++) {
      final blob = blobs[i];
      final aspectRatio = blob.width / blob.height;

      final isLargeEnoughToInspect =
          blob.pixelCount >= 100 || blob.width >= 20 || blob.height >= 20;

      if (isLargeEnoughToInspect) {
        print(
          'BLOB[$i] '
          'pixels=${blob.pixelCount} '
          'size=${blob.width}x${blob.height} '
          'centroid=(${blob.centroidX.toStringAsFixed(1)}, '
          '${blob.centroidY.toStringAsFixed(1)}) '
          'aspect=${aspectRatio.toStringAsFixed(3)} '
          'fill=${blob.fillRatio.toStringAsFixed(3)}',
        );
      }

      final candidate = _createBallCandidate(blob);

      if (candidate != null) {
        candidates.add(candidate);

        print(
          '  -> PASS '
          'center=(${candidate.centerX.toStringAsFixed(1)}, '
          '${candidate.centerY.toStringAsFixed(1)}) '
          'radius=${candidate.radius.toStringAsFixed(1)} '
          'confidence=${candidate.confidence.toStringAsFixed(3)}',
        );
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    print('===== BlobFilter result: ${candidates.length} candidates =====');

    return candidates;
  }

  static BallCandidate? _createBallCandidate(Blob blob) {
    if (blob.pixelCount < minimumPixelCount) {
      return null;
    }

    if (blob.width < minimumDiameter || blob.height < minimumDiameter) {
      return null;
    }

    if (blob.width > maximumDiameter || blob.height > maximumDiameter) {
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

    final centerX = (blob.minX + blob.maxX) / 2.0;
    final centerY = (blob.minY + blob.maxY) / 2.0;

    return BallCandidate(
      centerX: centerX,
      centerY: centerY,
      radius: estimatedRadius,
      confidence: confidence,
    );
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
