class HsvColorValue {
  const HsvColorValue({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;
}

class ColorDetector {
  const ColorDetector._();

  static HsvColorValue rgbToHsv({
    required int red,
    required int green,
    required int blue,
  }) {
    final r = red / 255.0;
    final g = green / 255.0;
    final b = blue / 255.0;

    final maxValue = [r, g, b].reduce((a, b) => a > b ? a : b);
    final minValue = [r, g, b].reduce((a, b) => a < b ? a : b);
    final difference = maxValue - minValue;

    double hue;

    if (difference == 0) {
      hue = 0;
    } else if (maxValue == r) {
      hue = 60 * (((g - b) / difference) % 6);
    } else if (maxValue == g) {
      hue = 60 * (((b - r) / difference) + 2);
    } else {
      hue = 60 * (((r - g) / difference) + 4);
    }

    if (hue < 0) {
      hue += 360;
    }

    final saturation = maxValue == 0 ? 0.0 : difference / maxValue;

    return HsvColorValue(hue: hue, saturation: saturation, value: maxValue);
  }

  static bool isYellow(HsvColorValue hsv) {
    return hsv.hue >= 40 &&
        hsv.hue <= 75 &&
        hsv.saturation >= 0.35 &&
        hsv.value >= 0.35;
  }

  static bool isRed(HsvColorValue hsv) {
    final isRedHue = hsv.hue <= 15 || hsv.hue >= 345;

    return isRedHue && hsv.saturation >= 0.35 && hsv.value >= 0.25;
  }
}
