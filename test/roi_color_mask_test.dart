import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/roi_color_mask.dart';

void main() {
  test('ROI mask preserves original image coordinates', () {
    final mask = RoiColorMask(
      originX: 100,
      originY: 200,
      width: 4,
      height: 3,
    );

    expect(mask.pixels.length, 12);

    mask.setPixel(101, 201, true);
    mask.setPixel(103, 202, true);

    expect(mask.getPixel(101, 201), isTrue);
    expect(mask.getPixel(103, 202), isTrue);
    expect(mask.getPixel(100, 200), isFalse);
    expect(mask.getPixel(99, 201), isFalse);
    expect(mask.getPixel(104, 201), isFalse);

    mask.setPixel(101, 201, false);
    expect(mask.getPixel(101, 201), isFalse);
  });

  test('ROI mask rejects writes outside its bounds', () {
    final mask = RoiColorMask(
      originX: 100,
      originY: 200,
      width: 4,
      height: 3,
    );

    expect(
      () => mask.setPixel(99, 200, true),
      throwsRangeError,
    );

    expect(
      () => mask.setPixel(104, 200, true),
      throwsRangeError,
    );
  });

  test('ROI mask supports empty regions', () {
    final mask = RoiColorMask(
      originX: 100,
      originY: 200,
      width: 0,
      height: 0,
    );

    expect(mask.pixels, isEmpty);
    expect(mask.getPixel(100, 200), isFalse);
  });
}
