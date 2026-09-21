import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'blob_analyzer.dart';
import 'color_detector.dart';
import 'color_mask.dart';

class GreenMarkerDiagnostic {
  const GreenMarkerDiagnostic._();

  static void inspect(Uint8List imageBytes, {required int frameIndex}) {
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      debugPrint(
        'GREEN DIAGNOSTIC ERROR frameIndex=$frameIndex image decode failed',
      );
      return;
    }

    var count = 0;
    final greenMask = ColorMask(width: image.width, height: image.height);

    var minR = 255;
    var maxR = 0;
    var minG = 255;
    var maxG = 0;
    var minB = 255;
    var maxB = 0;

    var minH = 360.0;
    var maxH = 0.0;
    var minS = 1.0;
    var maxS = 0.0;
    var minV = 1.0;
    var maxV = 0.0;

    var sumR = 0.0;
    var sumG = 0.0;
    var sumB = 0.0;
    var sumH = 0.0;
    var sumS = 0.0;
    var sumV = 0.0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final red = pixel.r.toInt();
        final green = pixel.g.toInt();
        final blue = pixel.b.toInt();

        final hsv = ColorDetector.rgbToHsv(red: red, green: green, blue: blue);

        // Diagnostic only:
        // deliberately broad green range.
        final looksGreen =
            hsv.hue >= 80 &&
            hsv.hue <= 180 &&
            hsv.saturation >= 0.25 &&
            hsv.value >= 0.15;

        greenMask.setPixel(x, y, looksGreen);

        if (!looksGreen) {
          continue;
        }

        count++;

        if (red < minR) minR = red;
        if (red > maxR) maxR = red;
        if (green < minG) minG = green;
        if (green > maxG) maxG = green;
        if (blue < minB) minB = blue;
        if (blue > maxB) maxB = blue;

        if (hsv.hue < minH) minH = hsv.hue;
        if (hsv.hue > maxH) maxH = hsv.hue;
        if (hsv.saturation < minS) minS = hsv.saturation;
        if (hsv.saturation > maxS) maxS = hsv.saturation;
        if (hsv.value < minV) minV = hsv.value;
        if (hsv.value > maxV) maxV = hsv.value;

        sumR += red;
        sumG += green;
        sumB += blue;
        sumH += hsv.hue;
        sumS += hsv.saturation;
        sumV += hsv.value;
      }
    }

    final blobs = BlobAnalyzer.extractBlobs(greenMask, minimumPixelCount: 100);

    debugPrint(
      'GREEN DIAGNOSTIC '
      'frameIndex=$frameIndex '
      'image=${image.width}x${image.height} '
      'pixels=$count '
      'blobs=${blobs.length}',
    );

    for (final blob in blobs) {
      final accepted = blob.width >= 20 && blob.height >= 15;

      debugPrint(
        'GREEN BLOB DEBUG '
        'accepted=$accepted '
        'x=${blob.centroidX.toStringAsFixed(1)} '
        'y=${blob.centroidY.toStringAsFixed(1)} '
        'width=${blob.width} '
        'height=${blob.height} '
        'pixels=${blob.pixelCount} '
        'fill=${blob.fillRatio.toStringAsFixed(3)}',
      );
    }

    if (count == 0) {
      return;
    }

    debugPrint(
      'GREEN DIAGNOSTIC RGB '
      'R=$minR..$maxR avg=${(sumR / count).toStringAsFixed(1)} '
      'G=$minG..$maxG avg=${(sumG / count).toStringAsFixed(1)} '
      'B=$minB..$maxB avg=${(sumB / count).toStringAsFixed(1)}',
    );

    debugPrint(
      'GREEN DIAGNOSTIC HSV '
      'H=${minH.toStringAsFixed(1)}..${maxH.toStringAsFixed(1)} '
      'avg=${(sumH / count).toStringAsFixed(1)} '
      'S=${minS.toStringAsFixed(3)}..${maxS.toStringAsFixed(3)} '
      'avg=${(sumS / count).toStringAsFixed(3)} '
      'V=${minV.toStringAsFixed(3)}..${maxV.toStringAsFixed(3)} '
      'avg=${(sumV / count).toStringAsFixed(3)}',
    );
  }
}
