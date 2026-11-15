import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/models/blob.dart';
import 'package:putt_physics_v1/services/blob_analyzer.dart';
import 'package:putt_physics_v1/services/color_scanner.dart';

void main() {
  test('ROI blob extraction matches original extraction', () {
    final image = img.Image(width: 30, height: 24);

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 0, 0, 255);
      }
    }

    // Two separate red regions.
    for (var y = 6; y < 9; y++) {
      for (var x = 7; x < 11; x++) {
        image.setPixelRgb(x, y, 255, 0, 0);
      }
    }
    for (var y = 14; y < 18; y++) {
      for (var x = 17; x < 20; x++) {
        image.setPixelRgb(x, y, 255, 0, 0);
      }
    }

    // One yellow region.
    for (var y = 10; y < 13; y++) {
      for (var x = 12; x < 16; x++) {
        image.setPixelRgb(x, y, 255, 255, 0);
      }
    }

    const minX = 5;
    const minY = 4;
    const maxX = 25;
    const maxY = 21;

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

    final oldBlobs = BlobAnalyzer.extractThreeMasks(
      combinedMask: original.mask,
      yellowMask: original.yellowMask,
      redMask: original.redMask,
      minimumPixelCount: 1,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    final newBlobs = BlobAnalyzer.extractThreeRoiMasks(
      combinedMask: roi.mask,
      yellowMask: roi.yellowMask,
      redMask: roi.redMask,
      minimumPixelCount: 1,
    );

    void compare(List<Blob> expected, List<Blob> actual) {
      expect(actual.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(actual[i].pixelCount, expected[i].pixelCount);
        expect(actual[i].minX, expected[i].minX);
        expect(actual[i].minY, expected[i].minY);
        expect(actual[i].maxX, expected[i].maxX);
        expect(actual[i].maxY, expected[i].maxY);
        expect(actual[i].centroidX, expected[i].centroidX);
        expect(actual[i].centroidY, expected[i].centroidY);
      }
    }

    compare(oldBlobs.$1, newBlobs.$1);
    compare(oldBlobs.$2, newBlobs.$2);
    compare(oldBlobs.$3, newBlobs.$3);
  });
}
