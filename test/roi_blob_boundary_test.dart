import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/models/blob.dart';
import 'package:putt_physics_v1/services/blob_analyzer.dart';
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('ROI boundary blobs match the original implementation', () {
    final image = img.Image(width: 20, height: 16);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 0, 0, 255);
      }
    }

    // Red region crosses the top and left ROI boundaries.
    for (var y = 2; y < 7; y++) {
      for (var x = 3; x < 8; x++) {
        image.setPixelRgb(x, y, 255, 0, 0);
      }
    }

    // Yellow region crosses the bottom and right ROI boundaries.
    for (var y = 9; y < 14; y++) {
      for (var x = 12; x < 17; x++) {
        image.setPixelRgb(x, y, 255, 255, 0);
      }
    }

    const minX = 5;
    const minY = 4;
    const maxX = 15;
    const maxY = 12;

    final original = ColorScanner.scan(
      image,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    final roi = ColorScanner.scanRoi(
      image,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    final expected = BlobAnalyzer.extractThreeMasks(
      combinedMask: original.mask,
      yellowMask: original.yellowMask,
      redMask: original.redMask,
      minimumPixelCount: 1,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    final actual = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: roi.mask,
      yellowMask: roi.yellowMask,
      redMask: roi.redMask,
      minimumPixelCount: 1,
    );

    void compare(List<Blob> a, List<Blob> b) {
      expect(b.length, a.length);
      for (var i = 0; i < a.length; i++) {
        expect(b[i].pixelCount, a[i].pixelCount);
        expect(b[i].minX, a[i].minX);
        expect(b[i].minY, a[i].minY);
        expect(b[i].maxX, a[i].maxX);
        expect(b[i].maxY, a[i].maxY);
        expect(b[i].centroidX, a[i].centroidX);
        expect(b[i].centroidY, a[i].centroidY);
      }
    }

    compare(expected.$1, actual.$1);
    compare(expected.$2, actual.$2);
    compare(expected.$3, actual.$3);

    expect(actual.$2.single.pixelCount, 9);
    expect(actual.$3.single.pixelCount, 9);
  });
}
