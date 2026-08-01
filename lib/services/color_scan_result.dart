class ColorScanResult {
  const ColorScanResult({
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
  });

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;

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
