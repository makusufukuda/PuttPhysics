import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/color_detector.dart';

void main() {
  testColorBoundaries();
  group('ColorDetector', () {
    test('recognizes primary colors', () {
      final red = ColorDetector.rgbToHsv(red: 255, green: 0, blue: 0);
      final yellow = ColorDetector.rgbToHsv(red: 255, green: 255, blue: 0);
      final blue = ColorDetector.rgbToHsv(red: 0, green: 0, blue: 255);
      expect(ColorDetector.isRed(red), isTrue);
      expect(ColorDetector.isYellow(yellow), isTrue);
      expect(ColorDetector.isRed(blue), isFalse);
      expect(ColorDetector.isYellow(blue), isFalse);
    });
  });
}

void testColorBoundaries() {
  test('yellow hue boundaries', () {
    const insideLow = HsvColorValue(hue: 40, saturation: 0.35, value: 0.35);
    const insideHigh = HsvColorValue(hue: 90, saturation: 0.35, value: 0.35);
    const outside = HsvColorValue(hue: 39.9, saturation: 0.35, value: 0.35);

    expect(ColorDetector.isYellow(insideLow), isTrue);
    expect(ColorDetector.isYellow(insideHigh), isTrue);
    expect(ColorDetector.isYellow(outside), isFalse);
  });

  test('red hue boundaries', () {
    const low = HsvColorValue(hue: 15, saturation: 0.35, value: 0.25);
    const high = HsvColorValue(hue: 345, saturation: 0.35, value: 0.25);
    const outside = HsvColorValue(hue: 16, saturation: 0.35, value: 0.25);

    expect(ColorDetector.isRed(low), isTrue);
    expect(ColorDetector.isRed(high), isTrue);
    expect(ColorDetector.isRed(outside), isFalse);
  });
}
