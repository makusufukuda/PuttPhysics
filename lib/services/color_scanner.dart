import 'package:image/image.dart' as img;

import 'color_detector.dart';
import 'color_mask.dart';
import 'color_scan_result.dart';
import 'roi_color_mask.dart';
import 'roi_color_scan_result.dart';

class ColorScanner {
  const ColorScanner._();

  static RoiColorScanResult scanRoi(
    img.Image image, {
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
  }) {
    final startX = minX.clamp(0, image.width);
    final startY = minY.clamp(0, image.height);
    final endX = maxX.clamp(startX, image.width);
    final endY = maxY.clamp(startY, image.height);

    final width = endX - startX;
    final height = endY - startY;

    final mask = RoiColorMask(
      originX: startX,
      originY: startY,
      width: width,
      height: height,
    );
    final yellowMask = RoiColorMask(
      originX: startX,
      originY: startY,
      width: width,
      height: height,
    );
    final redMask = RoiColorMask(
      originX: startX,
      originY: startY,
      width: width,
      height: height,
    );

    var yellowPixels = 0;
    var redPixels = 0;
    var scannedPixels = 0;
    var skippedDarkPixels = 0;

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final pixel = image.getPixel(x, y);
        scannedPixels++;

        final red = pixel.r.toInt();
        final green = pixel.g.toInt();
        final blue = pixel.b.toInt();

        final isTooDark = red < 64 && green < 64 && blue < 64;

        final bool isYellow;
        final bool isRed;

        if (isTooDark) {
          skippedDarkPixels++;
          isYellow = false;
          isRed = false;
        } else {
          final hsv = ColorDetector.rgbToHsv(
            red: red,
            green: green,
            blue: blue,
          );
          isYellow = ColorDetector.isYellow(hsv);
          isRed = ColorDetector.isRed(hsv);
        }

        if (isYellow) yellowPixels++;
        if (isRed) redPixels++;

        final index = (y - startY) * width + (x - startX);
        yellowMask.pixels[index] = isYellow;
        redMask.pixels[index] = isRed;
        mask.pixels[index] = isYellow || isRed;
      }
    }

    return RoiColorScanResult(
      totalPixels: image.width * image.height,
      yellowPixels: yellowPixels,
      redPixels: redPixels,
      scannedPixels: scannedPixels,
      skippedDarkPixels: skippedDarkPixels,
      mask: mask,
      yellowMask: yellowMask,
      redMask: redMask,
    );
  }

  static ColorScanResult scan(
    img.Image image, {
    int? minX,
    int? minY,
    int? maxX,
    int? maxY,
  }) {
    var yellowPixels = 0;
    var redPixels = 0;
    var scannedPixels = 0;
    var skippedDarkPixels = 0;

    final mask = ColorMask(width: image.width, height: image.height);

    final yellowMask = ColorMask(width: image.width, height: image.height);

    final redMask = ColorMask(width: image.width, height: image.height);

    final startX = (minX ?? 0).clamp(0, image.width);
    final startY = (minY ?? 0).clamp(0, image.height);
    final endX = (maxX ?? image.width).clamp(0, image.width);
    final endY = (maxY ?? image.height).clamp(0, image.height);

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final pixel = image.getPixel(x, y);
        scannedPixels++;

        final red = pixel.r.toInt();
        final green = pixel.g.toInt();
        final blue = pixel.b.toInt();

        // 明度が0.25未満なら赤・黄のどちらにも該当しない。
        final isTooDark = red < 64 && green < 64 && blue < 64;

        final bool isYellow;
        final bool isRed;

        if (isTooDark) {
          skippedDarkPixels++;
          isYellow = false;
          isRed = false;
        } else {
          final hsv = ColorDetector.rgbToHsv(
            red: red,
            green: green,
            blue: blue,
          );
          isYellow = ColorDetector.isYellow(hsv);
          isRed = ColorDetector.isRed(hsv);
        }

        if (isYellow) {
          yellowPixels++;
        }

        if (isRed) {
          redPixels++;
        }

        final index = y * image.width + x;
        yellowMask.pixels[index] = isYellow;
        redMask.pixels[index] = isRed;

        // 従来処理も残す
        mask.pixels[index] = isYellow || isRed;
      }
    }

    return ColorScanResult(
      totalPixels: image.width * image.height,
      yellowPixels: yellowPixels,
      redPixels: redPixels,
      scannedPixels: scannedPixels,
      skippedDarkPixels: skippedDarkPixels,
      mask: mask,
      yellowMask: yellowMask,
      redMask: redMask,
    );
  }
}
