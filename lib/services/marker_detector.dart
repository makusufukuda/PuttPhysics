import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/blob.dart';
import '../models/marker_candidate.dart';
import 'blob_analyzer.dart';
import 'color_detector.dart';
import 'color_mask.dart';

class MarkerDetector {
  const MarkerDetector._();

  static List<MarkerCandidate> detect(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      return const [];
    }

    final blueMask = ColorMask(width: image.width, height: image.height);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final red = pixel.r.toInt();
        final green = pixel.g.toInt();
        final blue = pixel.b.toInt();

        final hsv = ColorDetector.rgbToHsv(red: red, green: green, blue: blue);

        final isBlue =
            hsv.hue >= 205 &&
            hsv.hue <= 255 &&
            hsv.saturation >= 0.20 &&
            hsv.value >= 0.15;

        blueMask.setPixel(x, y, isBlue);
      }
    }

    // Diagnostic: keep smaller blue blobs so we can determine whether
    // distant calibration markers are being discarded by the 100-pixel cutoff.
    final blobs = BlobAnalyzer.extractBlobs(blueMask, minimumPixelCount: 20);

    final markerBlobs = _removeNearbyDuplicates(
      blobs.where(_looksLikeMarker).toList(),
    );

    debugPrint(
      'MARKER DEBUG image=${image.width}x${image.height} '
      'blueBlobs=${blobs.length} markerBlobs=${markerBlobs.length}',
    );

    for (final blob in blobs) {
      final aspectRatio = blob.width / blob.height;
      final accepted = _looksLikeMarker(blob);

      debugPrint(
        'MARKER BLOB DEBUG '
        'accepted=$accepted '
        'x=${blob.centroidX.toStringAsFixed(1)} '
        'y=${blob.centroidY.toStringAsFixed(1)} '
        'width=${blob.width} '
        'height=${blob.height} '
        'pixels=${blob.pixelCount} '
        'aspect=${aspectRatio.toStringAsFixed(3)} '
        'fill=${blob.fillRatio.toStringAsFixed(3)}',
      );
    }

    if (markerBlobs.length < 4) {
      return const [];
    }

    final selectedBlobs = markerBlobs.length == 4
        ? markerBlobs
        : _selectBestFourMarkerBlobs(markerBlobs);

    if (selectedBlobs == null) {
      return const [];
    }

    final sortedByY = [...selectedBlobs]
      ..sort((a, b) => a.centroidY.compareTo(b.centroidY));

    final topRow = sortedByY.sublist(0, 2)
      ..sort((a, b) => a.centroidX.compareTo(b.centroidX));

    final bottomRow = sortedByY.sublist(2, 4)
      ..sort((a, b) => a.centroidX.compareTo(b.centroidX));

    final positionedBlobs = <MarkerPosition, Blob>{
      MarkerPosition.topLeft: topRow[0],
      MarkerPosition.topRight: topRow[1],
      MarkerPosition.bottomLeft: bottomRow[0],
      MarkerPosition.bottomRight: bottomRow[1],
    };

    final results = <MarkerCandidate>[];

    for (final entry in positionedBlobs.entries) {
      final blob = entry.value;

      results.add(
        MarkerCandidate(
          position: entry.key,
          centerX: blob.centroidX,
          centerY: blob.centroidY,
          width: blob.width,
          height: blob.height,
          pixelCount: blob.pixelCount,
        ),
      );
    }

    return results;
  }

  static List<Blob> _removeNearbyDuplicates(List<Blob> blobs) {
    final sorted = [...blobs]
      ..sort((a, b) => b.pixelCount.compareTo(a.pixelCount));

    final kept = <Blob>[];

    for (final blob in sorted) {
      final overlapsExisting = kept.any((existing) {
        final dx = blob.centroidX - existing.centroidX;
        final dy = blob.centroidY - existing.centroidY;

        final distanceSquared = (dx * dx) + (dy * dy);

        final smallerSize = [
          blob.width,
          blob.height,
          existing.width,
          existing.height,
        ].reduce((a, b) => a < b ? a : b);

        final limit = smallerSize / 2.0;

        final centerInsideExisting =
            blob.centroidX >= existing.minX &&
            blob.centroidX <= existing.maxX &&
            blob.centroidY >= existing.minY &&
            blob.centroidY <= existing.maxY;

        return distanceSquared <= limit * limit || centerInsideExisting;
      });

      if (!overlapsExisting) {
        kept.add(blob);
      }
    }

    return kept;
  }

  static List<Blob>? selectBestFourMarkerBlobsForTesting(List<Blob> blobs) {
    final markerBlobs = _removeNearbyDuplicates(
      blobs.where(_looksLikeMarker).toList(),
    );

    if (markerBlobs.length < 4) {
      return null;
    }

    return markerBlobs.length == 4
        ? markerBlobs
        : _selectBestFourMarkerBlobs(markerBlobs);
  }

  static List<Blob>? _selectBestFourMarkerBlobs(List<Blob> blobs) {
    if (blobs.length < 4) {
      return null;
    }

    List<Blob>? bestSelection;
    double? bestScore;

    for (var a = 0; a < blobs.length - 3; a++) {
      for (var b = a + 1; b < blobs.length - 2; b++) {
        for (var c = b + 1; c < blobs.length - 1; c++) {
          for (var d = c + 1; d < blobs.length; d++) {
            final selection = [blobs[a], blobs[b], blobs[c], blobs[d]]
              ..sort((x, y) => x.centroidY.compareTo(y.centroidY));

            final topLeftOrRight = selection[0];
            final topRightOrLeft = selection[1];
            final bottomLeftOrRight = selection[2];
            final bottomRightOrLeft = selection[3];

            final topYDifference =
                (topLeftOrRight.centroidY - topRightOrLeft.centroidY).abs();
            final bottomYDifference =
                (bottomLeftOrRight.centroidY - bottomRightOrLeft.centroidY)
                    .abs();

            final topHorizontalSpan =
                (topLeftOrRight.centroidX - topRightOrLeft.centroidX).abs();
            final bottomHorizontalSpan =
                (bottomLeftOrRight.centroidX - bottomRightOrLeft.centroidX)
                    .abs();

            final spanDifference = (topHorizontalSpan - bottomHorizontalSpan)
                .abs();

            final score =
                topYDifference + bottomYDifference + (spanDifference * 0.25);

            if (bestScore == null || score < bestScore) {
              bestScore = score;
              bestSelection = List<Blob>.from(selection);
            }
          }
        }
      }
    }

    return bestSelection;
  }

  static bool _looksLikeMarker(Blob blob) {
    final width = blob.maxX - blob.minX + 1;
    final height = blob.maxY - blob.minY + 1;

    // Perspective makes the far calibration markers much smaller than
    // the near markers in the current rear-camera setup.
    if (width < 6 || height < 6) {
      return false;
    }

    if (width > 130 || height > 130) {
      return false;
    }

    final aspectRatio = width / height;

    if (aspectRatio < 0.60 || aspectRatio > 2.20) {
      return false;
    }

    final boundingArea = width * height;
    final fillRatio = blob.pixelCount / boundingArea;

    return fillRatio >= 0.25;
  }
}
