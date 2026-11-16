import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/ball_candidate.dart';
import '../models/blob.dart';
import 'blob_analyzer.dart';
import 'blob_filter.dart';
import 'color_detector.dart';
import 'color_scanner.dart';
import 'frame_extractor.dart';

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

  static (int, int, int) _readBgraCenterRgb({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    if (width <= 0 ||
        height <= 0 ||
        bytesPerRow < width * 4 ||
        bytes.lengthInBytes != bytesPerRow * height) {
      throw StateError('Invalid BGRA frame data.');
    }

    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final offset = centerY * bytesPerRow + centerX * 4;

    final blue = bytes[offset];
    final green = bytes[offset + 1];
    final red = bytes[offset + 2];

    return (red, green, blue);
  }

  static Blob _translateBlobToGlobal(
    Blob blob, {
    required int offsetX,
    required int offsetY,
  }) {
    return Blob(
      pixelCount: blob.pixelCount,
      minX: blob.minX + offsetX,
      minY: blob.minY + offsetY,
      maxX: blob.maxX + offsetX,
      maxY: blob.maxY + offsetY,
      centroidX: blob.centroidX + offsetX,
      centroidY: blob.centroidY + offsetY,
    );
  }

  static ImageInfoResult? inspectFrameRoi(
    ExtractedVideoFrame frame, {
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
    int? debugFrameIndex,
  }) {
    final width = frame.width;
    final height = frame.height;
    final bytesPerRow = frame.bytesPerRow;

    if (frame.pixelFormat != 'BGRA8888' ||
        width == null ||
        height == null ||
        bytesPerRow == null) {
      throw StateError('ROI inspection requires BGRA8888 frame metadata.');
    }

    final x1 = minX.clamp(0, width);
    final y1 = minY.clamp(0, height);
    final x2 = maxX.clamp(0, width);
    final y2 = maxY.clamp(0, height);

    if (x2 <= x1 || y2 <= y1) {
      return null;
    }

    final roiImage = FrameExtractor.decodeFrameRoi(
      frame,
      minX: x1,
      minY: y1,
      maxX: x2,
      maxY: y2,
    );

    if (roiImage == null) {
      return null;
    }

    final (centerRed, centerGreen, centerBlue) = _readBgraCenterRgb(
      bytes: frame.imageBytes,
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
    );

    final centerHsv = ColorDetector.rgbToHsv(
      red: centerRed,
      green: centerGreen,
      blue: centerBlue,
    );

    final roiScanResult = ColorScanner.scanRoi(
      roiImage,
      minX: 0,
      minY: 0,
      maxX: roiImage.width,
      maxY: roiImage.height,
      originalTotalPixels: width * height,
    );

    final (
      localBlobs,
      localYellowBlobs,
      localRedBlobs,
    ) = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: roiScanResult.mask,
      yellowMask: roiScanResult.yellowMask,
      redMask: roiScanResult.redMask,
      minimumPixelCount: _minimumBlobPixelCount,
    );

    final blobs = [
      for (final blob in localBlobs)
        _translateBlobToGlobal(blob, offsetX: x1, offsetY: y1),
    ];

    final yellowBlobs = [
      for (final blob in localYellowBlobs)
        _translateBlobToGlobal(blob, offsetX: x1, offsetY: y1),
    ];

    final redBlobs = [
      for (final blob in localRedBlobs)
        _translateBlobToGlobal(blob, offsetX: x1, offsetY: y1),
    ];

    final (
      largestBlob,
      ballCandidates,
      bestBallCandidate,
    ) = _analyzeBallCandidates(
      blobs: blobs,
      yellowBlobs: yellowBlobs,
      redBlobs: redBlobs,
      debugFrameIndex: debugFrameIndex,
    );

    return ImageInfoResult(
      width: width,
      height: height,
      centerX: width ~/ 2,
      centerY: height ~/ 2,
      centerRed: centerRed,
      centerGreen: centerGreen,
      centerBlue: centerBlue,
      centerHue: centerHsv.hue,
      centerSaturation: centerHsv.saturation,
      centerValue: centerHsv.value,
      centerIsYellow: ColorDetector.isYellow(centerHsv),
      centerIsRed: ColorDetector.isRed(centerHsv),
      totalPixels: roiScanResult.totalPixels,
      yellowPixels: roiScanResult.yellowPixels,
      redPixels: roiScanResult.redPixels,
      targetColorPixels: roiScanResult.targetColorPixels,
      yellowRatio: roiScanResult.yellowRatio,
      redRatio: roiScanResult.redRatio,
      blobCount: blobs.length,
      largestBlob: largestBlob,
      ballCandidateCount: ballCandidates.length,
      ballCandidates: ballCandidates,
      bestBallCandidate: bestBallCandidate,
    );
  }

  static ImageInfoResult? inspect(
    Uint8List imageBytes, {
    int? debugFrameIndex,
  }) {
    final decodeWatch = Stopwatch()..start();
    final image = img.decodeImage(imageBytes);
    decodeWatch.stop();
    if (debugFrameIndex != null && debugFrameIndex <= 20) {
      debugPrint(
        "IMAGE DECODE TIMING frame=$debugFrameIndex ms=${(decodeWatch.elapsedMicroseconds / 1000).toStringAsFixed(2)}",
      );
    }

    if (image == null) {
      return null;
    }

    return inspectDecoded(image, debugFrameIndex: debugFrameIndex);
  }

  static ImageInfoResult inspectDecoded(
    img.Image image, {
    int? debugFrameIndex,
    int? minX,
    int? minY,
    int? maxX,
    int? maxY,
  }) {
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

    final colorWatch = Stopwatch()..start();
    final useRoi = minX != null && minY != null && maxX != null && maxY != null;

    final roiScanResult = useRoi
        ? ColorScanner.scanRoi(
            image,
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
          )
        : null;

    final scanResult = useRoi
        ? null
        : ColorScanner.scan(
            image,
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
          );

    final scannedPixels =
        roiScanResult?.scannedPixels ?? scanResult!.scannedPixels;
    final skippedDarkPixels =
        roiScanResult?.skippedDarkPixels ?? scanResult!.skippedDarkPixels;
    final skippedDarkRatio =
        roiScanResult?.skippedDarkRatio ?? scanResult!.skippedDarkRatio;
    colorWatch.stop();
    if (debugFrameIndex != null && debugFrameIndex <= 20) {
      debugPrint(
        "COLOR SCAN TIMING frame=$debugFrameIndex "
        "ms=${(colorWatch.elapsedMicroseconds / 1000).toStringAsFixed(2)} "
        "scanned=$scannedPixels "
        "skippedDark=$skippedDarkPixels "
        "skippedPercent=${(skippedDarkRatio * 100).toStringAsFixed(1)}%",
      );
    }

    final blobWatch = Stopwatch()..start();
    final (blobs, yellowBlobs, redBlobs) = roiScanResult != null
        ? BlobAnalyzer.extractThreeRoiMasks(
            combinedMask: roiScanResult.mask,
            yellowMask: roiScanResult.yellowMask,
            redMask: roiScanResult.redMask,
            minimumPixelCount: _minimumBlobPixelCount,
          )
        : BlobAnalyzer.extractThreeMasks(
            combinedMask: scanResult!.mask,
            yellowMask: scanResult.yellowMask,
            redMask: scanResult.redMask,
            minimumPixelCount: _minimumBlobPixelCount,
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
          );

    blobWatch.stop();
    if (debugFrameIndex != null && debugFrameIndex <= 20) {
      debugPrint(
        "BLOB ANALYSIS TIMING frame=$debugFrameIndex ms=${(blobWatch.elapsedMicroseconds / 1000).toStringAsFixed(2)}",
      );
    }

    if ((debugFrameIndex == 370 || debugFrameIndex == 390)) {
      const ballX = 511;
      const ballY = 1324;

      for (final blob in redBlobs) {
        final containsBall =
            blob.minX <= ballX &&
            ballX <= blob.maxX &&
            blob.minY <= ballY &&
            ballY <= blob.maxY;

        if (containsBall) {
          debugPrint(
            'RED BALL BLOB frame=$debugFrameIndex '
            'containsBall=$containsBall '
            '$blob',
          );
        }
      }
    }

    if (debugFrameIndex != null &&
        debugFrameIndex >= 388 &&
        debugFrameIndex <= 391) {
      for (final entry in [('RED', redBlobs), ('YELLOW', yellowBlobs)]) {
        final color = entry.$1;
        final colorBlobs = entry.$2;

        for (final blob in colorBlobs) {
          if (blob.centroidX >= 350 &&
              blob.centroidX <= 700 &&
              blob.centroidY >= 500 &&
              blob.centroidY <= 1600) {
            debugPrint(
              'BALL REGION BLOB frame=$debugFrameIndex '
              'color=$color $blob',
            );
          }
        }
      }
    }

    final (
      largestBlob,
      ballCandidates,
      bestBallCandidate,
    ) = _analyzeBallCandidates(
      blobs: blobs,
      yellowBlobs: yellowBlobs,
      redBlobs: redBlobs,
      debugFrameIndex: debugFrameIndex,
    );

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
      totalPixels: roiScanResult?.totalPixels ?? scanResult!.totalPixels,
      yellowPixels: roiScanResult?.yellowPixels ?? scanResult!.yellowPixels,
      redPixels: roiScanResult?.redPixels ?? scanResult!.redPixels,
      targetColorPixels:
          roiScanResult?.targetColorPixels ?? scanResult!.targetColorPixels,
      yellowRatio: roiScanResult?.yellowRatio ?? scanResult!.yellowRatio,
      redRatio: roiScanResult?.redRatio ?? scanResult!.redRatio,
      blobCount: blobs.length,
      largestBlob: largestBlob,
      ballCandidateCount: ballCandidates.length,
      ballCandidates: ballCandidates,
      bestBallCandidate: bestBallCandidate,
    );
  }

  static (Blob?, List<BallCandidate>, BallCandidate?) _analyzeBallCandidates({
    required List<Blob> blobs,
    required List<Blob> yellowBlobs,
    required List<Blob> redBlobs,
    int? debugFrameIndex,
  }) {
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

    // 色別のBlobもボール候補として評価する。
    ballCandidates.addAll(BlobFilter.filter(redBlobs));
    ballCandidates.addAll(BlobFilter.filter(yellowBlobs));

    if ((debugFrameIndex == 370 || debugFrameIndex == 390)) {
      final redCandidates = BlobFilter.filter(
        redBlobs,
        debugFrameIndex: debugFrameIndex,
      );

      for (final candidate in redCandidates) {
        debugPrint(
          'RED BALL CANDIDATE frame=$debugFrameIndex '
          'x=${candidate.centerX.toStringAsFixed(1)} '
          'y=${candidate.centerY.toStringAsFixed(1)} '
          'r=${candidate.radius.toStringAsFixed(1)} '
          'confidence=${candidate.confidence.toStringAsFixed(3)}',
        );
      }
    }

    if (debugFrameIndex != null && debugFrameIndex <= 20) {
      for (var i = 0; i < ballCandidates.length; i++) {
        final candidate = ballCandidates[i];

        final nearbyRed = redBlobs.where((blob) {
          final dx = blob.centroidX - candidate.centerX;
          final dy = blob.centroidY - candidate.centerY;
          final distance = (dx * dx + dy * dy);
          final limit = candidate.radius * 3.0;
          return distance <= limit * limit;
        }).toList();

        final nearbyYellow = yellowBlobs.where((blob) {
          final dx = blob.centroidX - candidate.centerX;
          final dy = blob.centroidY - candidate.centerY;
          final distance = (dx * dx + dy * dy);
          final limit = candidate.radius * 3.0;
          return distance <= limit * limit;
        }).toList();

        final nearbyRedPixels = nearbyRed.fold<int>(
          0,
          (sum, blob) => sum + blob.pixelCount,
        );

        final nearbyYellowPixels = nearbyYellow.fold<int>(
          0,
          (sum, blob) => sum + blob.pixelCount,
        );

        debugPrint(
          'CANDIDATE COLOR '
          'frame=$debugFrameIndex '
          'index=$i '
          'x=${candidate.centerX.toStringAsFixed(1)} '
          'y=${candidate.centerY.toStringAsFixed(1)} '
          'r=${candidate.radius.toStringAsFixed(1)} '
          'redBlobs=${nearbyRed.length} '
          'redPixels=$nearbyRedPixels '
          'yellowBlobs=${nearbyYellow.length} '
          'yellowPixels=$nearbyYellowPixels',
        );
      }
    }

    // 近接する赤・黄Blobを組み合わせる。
    // 最大Blobだけでは、背景の大きな領域が選ばれる場合がある。
    for (final redBlob in redBlobs) {
      if (redBlob.pixelCount < 50) continue;

      for (final yellowBlob in yellowBlobs) {
        if (yellowBlob.pixelCount < 50) continue;

        final combinedCandidate = _createCombinedRedYellowCandidate(
          redBlob: redBlob,
          yellowBlob: yellowBlob,
        );

        if (combinedCandidate != null) {
          ballCandidates.add(combinedCandidate);
        }
      }
    }

    // 同じ物体から生成された重複候補を除去する。
    ballCandidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    final uniqueCandidates = <BallCandidate>[];

    for (final candidate in ballCandidates) {
      final isDuplicate = uniqueCandidates.any((existing) {
        final dx = candidate.centerX - existing.centerX;
        final dy = candidate.centerY - existing.centerY;
        final distanceSquared = dx * dx + dy * dy;
        final tolerance = candidate.radius < existing.radius
            ? candidate.radius * 0.25
            : existing.radius * 0.25;

        final radiusDifference = (candidate.radius - existing.radius).abs();

        return distanceSquared <= tolerance * tolerance &&
            radiusDifference <= tolerance;
      });

      if (!isDuplicate) {
        uniqueCandidates.add(candidate);
      }
    }

    ballCandidates
      ..clear()
      ..addAll(uniqueCandidates);

    final bestBallCandidate = ballCandidates.isEmpty
        ? null
        : ballCandidates.first;

    return (largestBlob, ballCandidates, bestBallCandidate);
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

    if (width <= 0 || height <= 0 || width > 300 || height > 300) {
      return null;
    }

    final aspectRatio = width / height;

    // 横方向のモーションブラーを許容する。
    if (aspectRatio < 0.75 || aspectRatio > 2.5) {
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
}
