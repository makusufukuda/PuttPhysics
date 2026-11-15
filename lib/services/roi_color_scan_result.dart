import 'roi_color_mask.dart';

class RoiColorScanResult {
  const RoiColorScanResult({
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
    required this.scannedPixels,
    required this.skippedDarkPixels,
    required this.mask,
    required this.yellowMask,
    required this.redMask,
  });

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;
  final int scannedPixels;
  final int skippedDarkPixels;

  final RoiColorMask mask;
  final RoiColorMask yellowMask;
  final RoiColorMask redMask;

  int get targetColorPixels => yellowPixels + redPixels;

  double get yellowRatio =>
      totalPixels == 0 ? 0 : yellowPixels / totalPixels;

  double get redRatio =>
      totalPixels == 0 ? 0 : redPixels / totalPixels;

  double get skippedDarkRatio =>
      scannedPixels == 0 ? 0 : skippedDarkPixels / scannedPixels;
}
