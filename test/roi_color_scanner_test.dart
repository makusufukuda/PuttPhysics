import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('scanRoi matches scan within the same ROI', () {
    final image = img.Image(width: 8, height: 6);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if ((x + y) % 4 == 0) {
          image.setPixelRgb(x, y, 255, 0, 0);
        } else if ((x + y) % 4 == 1) {
          image.setPixelRgb(x, y, 255, 255, 0);
        } else if ((x + y) % 4 == 2) {
          image.setPixelRgb(x, y, 10, 10, 10);
        } else {
          image.setPixelRgb(x, y, 0, 0, 255);
        }
      }
    }

    const minX = 2;
    const minY = 1;
    const maxX = 7;
    const maxY = 5;

    final original = ColorScanner.scan(
      image,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    final roi = ColorScanner.scanRoi(
      image,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    expect(roi.totalPixels, original.totalPixels);
    expect(roi.yellowPixels, original.yellowPixels);
    expect(roi.redPixels, original.redPixels);
    expect(roi.scannedPixels, original.scannedPixels);
    expect(roi.skippedDarkPixels, original.skippedDarkPixels);

    expect(roi.mask.pixels.length, (maxX - minX) * (maxY - minY));

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        expect(roi.mask.getPixel(x, y), original.mask.getPixel(x, y));
        expect(
          roi.yellowMask.getPixel(x, y),
          original.yellowMask.getPixel(x, y),
        );
        expect(
          roi.redMask.getPixel(x, y),
          original.redMask.getPixel(x, y),
        );
      }
    }
  });
}
