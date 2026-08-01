import 'color_mask.dart';

class ColorScanResult {
  const ColorScanResult({
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
    required this.mask,
  });

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;
  final ColorMask mask;

  int get targetColorPixels => yellowPixels + redPixels;

  double get yellowRatio {
    if (totalPixels == 0) {
      return 0;
    }

    return yellowPixels / totalPixels;
  }

  double get redRatio {
    if (totalPixels == 0) {
      return 0;
    }

    return redPixels / totalPixels;
  }
}
