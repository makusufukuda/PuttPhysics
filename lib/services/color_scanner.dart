import 'package:image/image.dart' as img;

import 'color_detector.dart';
import 'color_scan_result.dart';

class ColorScanner {
  const ColorScanner._();

  static ColorScanResult scan(img.Image image) {
    var yellowPixels = 0;
    var redPixels = 0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);

        final hsv = ColorDetector.rgbToHsv(
          red: pixel.r.toInt(),
          green: pixel.g.toInt(),
          blue: pixel.b.toInt(),
        );

        if (ColorDetector.isYellow(hsv)) {
          yellowPixels++;
        }

        if (ColorDetector.isRed(hsv)) {
          redPixels++;
        }
      }
    }

    return ColorScanResult(
      totalPixels: image.width * image.height,
      yellowPixels: yellowPixels,
      redPixels: redPixels,
    );
  }
}
