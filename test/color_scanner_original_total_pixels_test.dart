import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('ROI scan preserves original frame pixel denominator', () {
    final image = img.Image(width: 20, height: 20);

    // Blue background.
    img.fill(image, color: img.ColorRgb8(0, 0, 255));

    // Red 10 x 10 region.
    img.fillRect(
      image,
      x1: 5,
      y1: 5,
      x2: 14,
      y2: 14,
      color: img.ColorRgb8(255, 0, 0),
    );

    final original = ColorScanner.scanRoi(
      image,
      minX: 0,
      minY: 0,
      maxX: 20,
      maxY: 20,
    );

    final adjusted = ColorScanner.scanRoi(
      image,
      minX: 0,
      minY: 0,
      maxX: 20,
      maxY: 20,
      originalTotalPixels: 240 * 180,
    );

    expect(original.totalPixels, 400);
    expect(adjusted.totalPixels, 43200);

    expect(adjusted.redPixels, original.redPixels);
    expect(adjusted.yellowPixels, original.yellowPixels);
    expect(adjusted.scannedPixels, original.scannedPixels);

    expect(adjusted.redPixels, 100);
    expect(adjusted.redRatio, closeTo(100 / 43200, 1e-10));
    expect(adjusted.yellowRatio, 0);
  });
}
