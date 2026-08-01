import '../models/blob.dart';
import 'color_mask.dart';

class BlobAnalyzer {
  const BlobAnalyzer._();

  static List<Blob> extractBlobs(ColorMask mask, {int minimumPixelCount = 1}) {
    final visited = List<bool>.filled(mask.width * mask.height, false);

    final blobs = <Blob>[];

    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        final index = y * mask.width + x;

        if (visited[index] || !mask.getPixel(x, y)) {
          continue;
        }

        final blob = _extractSingleBlob(
          mask: mask,
          startX: x,
          startY: y,
          visited: visited,
        );

        if (blob.pixelCount >= minimumPixelCount) {
          blobs.add(blob);
        }
      }
    }

    return blobs;
  }

  static Blob _extractSingleBlob({
    required ColorMask mask,
    required int startX,
    required int startY,
    required List<bool> visited,
  }) {
    final queueX = <int>[startX];
    final queueY = <int>[startY];

    var queueIndex = 0;

    var pixelCount = 0;
    var sumX = 0;
    var sumY = 0;

    var minX = startX;
    var minY = startY;
    var maxX = startX;
    var maxY = startY;

    visited[startY * mask.width + startX] = true;

    const directions = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];

    while (queueIndex < queueX.length) {
      final x = queueX[queueIndex];
      final y = queueY[queueIndex];
      queueIndex++;

      pixelCount++;
      sumX += x;
      sumY += y;

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      for (final direction in directions) {
        final nextX = x + direction.$1;
        final nextY = y + direction.$2;

        if (nextX < 0 ||
            nextX >= mask.width ||
            nextY < 0 ||
            nextY >= mask.height) {
          continue;
        }

        final nextIndex = nextY * mask.width + nextX;

        if (visited[nextIndex] || !mask.getPixel(nextX, nextY)) {
          continue;
        }

        visited[nextIndex] = true;
        queueX.add(nextX);
        queueY.add(nextY);
      }
    }

    return Blob(
      pixelCount: pixelCount,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      centroidX: sumX / pixelCount,
      centroidY: sumY / pixelCount,
    );
  }
}
