import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/blob.dart';
import '../models/putter_candidate.dart';
import 'blob_analyzer.dart';
import 'color_detector.dart';
import 'color_mask.dart';

class PutterDetector {
  const PutterDetector._();

  static List<PutterCandidate> detect(Uint8List imageBytes, {int? frameIndex}) {
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      return const [];
    }

    final pinkMask = ColorMask(width: image.width, height: image.height);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final hsv = ColorDetector.rgbToHsv(
          red: pixel.r.toInt(),
          green: pixel.g.toInt(),
          blue: pixel.b.toInt(),
        );

        pinkMask.setPixel(x, y, ColorDetector.isPink(hsv));
      }
    }

    final blobs = BlobAnalyzer.extractBlobs(
      pinkMask,
      minimumPixelCount: 100,
    ).where(_looksLikePutterBlob).toList();

    final candidates = <PutterCandidate>[];

    for (var i = 0; i < blobs.length - 1; i++) {
      for (var j = i + 1; j < blobs.length; j++) {
        final candidate = _createPairCandidate(blobs[i], blobs[j]);

        if (candidate != null) {
          candidates.add(candidate);
        }
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    if (frameIndex != null) {
      debugPrint(
        'PUTTER DETECTOR '
        'frame=$frameIndex '
        'pinkBlobs=${blobs.length} '
        'candidates=${candidates.length}',
      );

      for (final candidate in candidates) {
        debugPrint(
          'PUTTER CANDIDATE '
          'frame=$frameIndex '
          'x=${candidate.centerX.toStringAsFixed(1)} '
          'y=${candidate.centerY.toStringAsFixed(1)} '
          'width=${candidate.width.toStringAsFixed(1)} '
          'height=${candidate.height.toStringAsFixed(1)} '
          'blobs=${candidate.blobCount} '
          'confidence=${candidate.confidence.toStringAsFixed(3)}',
        );
      }
    }

    return candidates;
  }

  static bool _looksLikePutterBlob(Blob blob) {
    if (blob.width < 15 || blob.height < 8) {
      return false;
    }

    if (blob.width > 160 || blob.height > 100) {
      return false;
    }

    return blob.fillRatio >= 0.20;
  }

  static PutterCandidate? _createPairCandidate(Blob a, Blob b) {
    final yDifference = (a.centroidY - b.centroidY).abs();
    final xDifference = (a.centroidX - b.centroidX).abs();

    if (yDifference > 30) {
      return null;
    }

    if (xDifference < 15 || xDifference > 140) {
      return null;
    }

    final widthRatio = a.width > b.width
        ? a.width / b.width
        : b.width / a.width;
    final heightRatio = a.height > b.height
        ? a.height / b.height
        : b.height / a.height;

    if (widthRatio > 2.0 || heightRatio > 2.0) {
      return null;
    }

    final centerX = (a.centroidX + b.centroidX) / 2.0;
    final centerY = (a.centroidY + b.centroidY) / 2.0;

    final minX = a.minX < b.minX ? a.minX : b.minX;
    final maxX = a.maxX > b.maxX ? a.maxX : b.maxX;
    final minY = a.minY < b.minY ? a.minY : b.minY;
    final maxY = a.maxY > b.maxY ? a.maxY : b.maxY;

    final yScore = (1.0 - (yDifference / 30.0)).clamp(0.0, 1.0);
    final widthScore = (1.0 - ((widthRatio - 1.0) / 1.0)).clamp(0.0, 1.0);
    final heightScore = (1.0 - ((heightRatio - 1.0) / 1.0)).clamp(0.0, 1.0);

    final confidence =
        (yScore * 0.50) + (widthScore * 0.25) + (heightScore * 0.25);

    return PutterCandidate(
      centerX: centerX,
      centerY: centerY,
      width: (maxX - minX + 1).toDouble(),
      height: (maxY - minY + 1).toDouble(),
      blobCount: 2,
      confidence: confidence,
    );
  }
}
