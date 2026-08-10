import 'color_mask.dart';

class ColorScanResult {
  const ColorScanResult({
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
    required this.mask,
    required this.yellowMask,
    required this.redMask,
  });

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;

  // 従来の赤＋黄マスク
  final ColorMask mask;

  // 診断・今後の個別解析用
  final ColorMask yellowMask;
  final ColorMask redMask;

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
