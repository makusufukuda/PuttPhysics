import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('ColorScanner detects yellow and red pixels', () {
    final image = img.Image(width: 3, height: 1);

    image.setPixelRgb(0, 0, 255, 255, 0);
    image.setPixelRgb(1, 0, 255, 0, 0);
    image.setPixelRgb(2, 0, 0, 0, 255);

    final result = ColorScanner.scan(image);

    expect(result.totalPixels, 3);
    expect(result.yellowPixels, 1);
    expect(result.redPixels, 1);
    expect(result.targetColorPixels, 2);

    expect(result.yellowMask.pixels, [true, false, false]);
    expect(result.redMask.pixels, [false, true, false]);
    expect(result.mask.pixels, [true, true, false]);
  });

  test('ColorScanner limits detection to ROI', () {
    final image = img.Image(width: 4, height: 2);

    image.setPixelRgb(0, 0, 255, 0, 0);
    image.setPixelRgb(1, 0, 255, 255, 0);
    image.setPixelRgb(2, 0, 255, 0, 0);
    image.setPixelRgb(3, 1, 255, 255, 0);

    final result = ColorScanner.scan(
      image,
      minX: 1,
      minY: 0,
      maxX: 3,
      maxY: 1,
    );

    expect(result.totalPixels, 8);
    expect(result.redPixels, 1);
    expect(result.yellowPixels, 1);
    expect(result.targetColorPixels, 2);

    expect(result.mask.getPixel(0, 0), false);
    expect(result.yellowMask.getPixel(1, 0), true);
    expect(result.redMask.getPixel(2, 0), true);
    expect(result.mask.getPixel(3, 1), false);
  });

}
