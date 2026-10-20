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
}
