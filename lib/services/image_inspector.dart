import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/blob.dart';
import 'blob_analyzer.dart';
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
}

class ImageInspector {
  const ImageInspector._();

  static const int _minimumBlobPixelCount = 10;

  static ImageInfoResult? inspect(Uint8List imageBytes) {
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

    Blob? largestBlob;

    for (final blob in blobs) {
      if (largestBlob == null || blob.pixelCount > largestBlob.pixelCount) {
        largestBlob = blob;
      }
    }

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
    );
  }
}
