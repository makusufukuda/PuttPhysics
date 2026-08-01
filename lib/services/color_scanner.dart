import 'package:image/image.dart' as img;

import 'color_detector.dart';
import 'color_mask.dart';
import 'color_scan_result.dart';

class ColorScanner {
  const ColorScanner._();

  static ColorScanResult scan(img.Image image) {
    var yellowPixels = 0;
    var redPixels = 0;

    final mask = ColorMask(width: image.width, height: image.height);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final hsv = ColorDetector.rgbToHsv(
          red: pixel.r.toInt(),
          green: pixel.g.toInt(),
          blue: pixel.b.toInt(),
        );

        final isYellow = ColorDetector.isYellow(hsv);
        final isRed = ColorDetector.isRed(hsv);

        if (isYellow) {
          yellowPixels++;
        }

        if (isRed) {
          redPixels++;
        }

        mask.setPixel(x, y, isYellow || isRed);
      }
    }

    return ColorScanResult(
      totalPixels: image.width * image.height,
      yellowPixels: yellowPixels,
      redPixels: redPixels,
      mask: mask,
    );
  }
}
