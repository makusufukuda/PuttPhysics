import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'color_detector.dart';

class BlueMarkerDiagnostic {
  const BlueMarkerDiagnostic._();

  static void inspect(Uint8List imageBytes, {required int frameIndex}) {
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      debugPrint(
        'BLUE DIAGNOSTIC ERROR frameIndex=$frameIndex image decode failed',
      );
      return;
    }

    var count = 0;

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
        // deliberately broad blue range.
        final looksBlue =
            hsv.hue >= 190 &&
            hsv.hue <= 260 &&
            hsv.saturation >= 0.35 &&
            hsv.value >= 0.15;

        if (!looksBlue) {
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

    debugPrint(
      'BLUE DIAGNOSTIC '
      'frameIndex=$frameIndex '
      'image=${image.width}x${image.height} '
      'pixels=$count',
    );

    if (count == 0) {
      return;
    }

    debugPrint(
      'BLUE DIAGNOSTIC RGB '
      'R=$minR..$maxR avg=${(sumR / count).toStringAsFixed(1)} '
      'G=$minG..$maxG avg=${(sumG / count).toStringAsFixed(1)} '
      'B=$minB..$maxB avg=${(sumB / count).toStringAsFixed(1)}',
    );

    debugPrint(
      'BLUE DIAGNOSTIC HSV '
      'H=${minH.toStringAsFixed(1)}..${maxH.toStringAsFixed(1)} '
      'avg=${(sumH / count).toStringAsFixed(1)} '
      'S=${minS.toStringAsFixed(3)}..${maxS.toStringAsFixed(3)} '
      'avg=${(sumS / count).toStringAsFixed(3)} '
      'V=${minV.toStringAsFixed(3)}..${maxV.toStringAsFixed(3)} '
      'avg=${(sumV / count).toStringAsFixed(3)}',
    );
  }
}
