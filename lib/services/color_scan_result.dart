import 'color_mask.dart';

class ColorScanResult {
  const ColorScanResult({
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
    this.scannedPixels = 0,
    this.skippedDarkPixels = 0,
    required this.mask,
    required this.yellowMask,
    required this.redMask,
  });

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;

  // 診断用：実際に走査した画素数
  final int scannedPixels;

  // 診断用：HSV変換を省略した暗い画素数
  final int skippedDarkPixels;

  double get skippedDarkRatio {
    if (scannedPixels == 0) return 0;
    return skippedDarkPixels / scannedPixels;
  }

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
