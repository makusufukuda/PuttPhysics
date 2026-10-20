import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/color_mask.dart';

void main() {
  test('ColorMask stores pixel values independently', () {
    final mask = ColorMask(width: 3, height: 2);

    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 3; x++) {
        expect(mask.getPixel(x, y), isFalse);
      }
    }

    mask.setPixel(1, 0, true);
    mask.setPixel(2, 1, true);

    expect(mask.getPixel(1, 0), isTrue);
    expect(mask.getPixel(2, 1), isTrue);
    expect(mask.getPixel(0, 0), isFalse);
    expect(mask.getPixel(1, 1), isFalse);

    mask.setPixel(1, 0, false);
    expect(mask.getPixel(1, 0), isFalse);
  });
}
