import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/ball_candidate.dart';
import '../models/blob.dart';
import 'blob_analyzer.dart';
import 'blob_filter.dart';
import 'color_detector.dart';
import 'color_scanner.dart';

class ImageInfoResult {
  const ImageInfoResult({
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
    required this.centerRed,
    required this.centerGreen,
    required this.centerBlue,
    required this.centerHue,
    required this.centerSaturation,
    required this.centerValue,
    required this.centerIsYellow,
    required this.centerIsRed,
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
    required this.targetColorPixels,
    required this.yellowRatio,
    required this.redRatio,
    required this.blobCount,
    required this.largestBlob,
    required this.ballCandidateCount,
    required this.ballCandidates,
    required this.bestBallCandidate,
  });

  final int width;
  final int height;

  final int centerX;
  final int centerY;

  final int centerRed;
  final int centerGreen;
  final int centerBlue;

  final double centerHue;
  final double centerSaturation;
  final double centerValue;

  final bool centerIsYellow;
  final bool centerIsRed;

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;
  final int targetColorPixels;

  final double yellowRatio;
  final double redRatio;

  final int blobCount;
  final Blob? largestBlob;

  final int ballCandidateCount;
  final List<BallCandidate> ballCandidates;
  final BallCandidate? bestBallCandidate;
}

class ImageInspector {
  const ImageInspector._();

  static const int _minimumBlobPixelCount = 10;

  static ImageInfoResult? inspect(
    Uint8List imageBytes, {
    int? debugFrameIndex,
  }) {
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      return null;
    }

    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final centerPixel = image.getPixel(centerX, centerY);

    final centerRed = centerPixel.r.toInt();
    final centerGreen = centerPixel.g.toInt();
    final centerBlue = centerPixel.b.toInt();

    final centerHsv = ColorDetector.rgbToHsv(
      red: centerRed,
      green: centerGreen,
      blue: centerBlue,
    );

    final scanResult = ColorScanner.scan(image);

    final blobs = BlobAnalyzer.extractBlobs(
      scanResult.mask,
      minimumPixelCount: _minimumBlobPixelCount,
    );

    final yellowBlobs = BlobAnalyzer.extractBlobs(
      scanResult.yellowMask,
      minimumPixelCount: _minimumBlobPixelCount,
    );

    final redBlobs = BlobAnalyzer.extractBlobs(
      scanResult.redMask,
      minimumPixelCount: _minimumBlobPixelCount,
    );

    final largestYellowBlob = _findLargestBlob(yellowBlobs);
    final largestRedBlob = _findLargestBlob(redBlobs);

    Blob? largestBlob;

    for (final blob in blobs) {
      if (largestBlob == null || blob.pixelCount > largestBlob.pixelCount) {
        largestBlob = blob;
      }
    }

    final ballCandidates = BlobFilter.filter(
      blobs,
      debugFrameIndex: debugFrameIndex,
    );

    final combinedCandidate = _createCombinedRedYellowCandidate(
      redBlob: largestRedBlob,
      yellowBlob: largestYellowBlob,
    );

    if (combinedCandidate != null) {
      ballCandidates.add(combinedCandidate);
      ballCandidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    }

    final bestBallCandidate = ballCandidates.isEmpty
        ? null
        : ballCandidates.first;

    return ImageInfoResult(
      width: image.width,
      height: image.height,
      centerX: centerX,
      centerY: centerY,
      centerRed: centerRed,
      centerGreen: centerGreen,
      centerBlue: centerBlue,
      centerHue: centerHsv.hue,
      centerSaturation: centerHsv.saturation,
      centerValue: centerHsv.value,
      centerIsYellow: ColorDetector.isYellow(centerHsv),
      centerIsRed: ColorDetector.isRed(centerHsv),
      totalPixels: scanResult.totalPixels,
      yellowPixels: scanResult.yellowPixels,
      redPixels: scanResult.redPixels,
      targetColorPixels: scanResult.targetColorPixels,
      yellowRatio: scanResult.yellowRatio,
      redRatio: scanResult.redRatio,
      blobCount: blobs.length,
      largestBlob: largestBlob,
      ballCandidateCount: ballCandidates.length,
      ballCandidates: ballCandidates,
      bestBallCandidate: bestBallCandidate,
    );
  }

  static BallCandidate? _createCombinedRedYellowCandidate({
    required Blob? redBlob,
    required Blob? yellowBlob,
  }) {
    if (redBlob == null || yellowBlob == null) {
      return null;
    }

    final horizontalGap = redBlob.maxX < yellowBlob.minX
        ? yellowBlob.minX - redBlob.maxX - 1
        : yellowBlob.maxX < redBlob.minX
        ? redBlob.minX - yellowBlob.maxX - 1
        : 0;

    final verticalGap = redBlob.maxY < yellowBlob.minY
        ? yellowBlob.minY - redBlob.maxY - 1
        : yellowBlob.maxY < redBlob.minY
        ? redBlob.minY - yellowBlob.maxY - 1
        : 0;

    const maximumGap = 40;

    if (horizontalGap > maximumGap || verticalGap > maximumGap) {
      return null;
    }

    final minX = redBlob.minX < yellowBlob.minX
        ? redBlob.minX
        : yellowBlob.minX;
    final minY = redBlob.minY < yellowBlob.minY
        ? redBlob.minY
        : yellowBlob.minY;
    final maxX = redBlob.maxX > yellowBlob.maxX
        ? redBlob.maxX
        : yellowBlob.maxX;
    final maxY = redBlob.maxY > yellowBlob.maxY
        ? redBlob.maxY
        : yellowBlob.maxY;

    final width = maxX - minX + 1;
    final height = maxY - minY + 1;

    if (width <= 0 || height <= 0) {
      return null;
    }

    final aspectRatio = width / height;

    if (aspectRatio < 0.75 || aspectRatio > 1.35) {
      return null;
    }

    final centerX = (minX + maxX) / 2.0;
    final centerY = (minY + maxY) / 2.0;
    final radius = (width + height) / 4.0;

    final aspectScore = 1.0 - (aspectRatio - 1.0).abs();

    final confidence = aspectScore.clamp(0.0, 1.0);

    return BallCandidate(
      centerX: centerX,
      centerY: centerY,
      radius: radius,
      confidence: confidence,
      isCombinedRedYellow: true,
    );
  }

  static Blob? _findLargestBlob(List<Blob> blobs) {
    Blob? largestBlob;

    for (final blob in blobs) {
      if (largestBlob == null || blob.pixelCount > largestBlob.pixelCount) {
        largestBlob = blob;
      }
    }

    return largestBlob;
  }
}
