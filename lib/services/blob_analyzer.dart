import '../models/blob.dart';
import 'color_mask.dart';
import 'roi_color_mask.dart';

class BlobAnalyzer {
  /// Extracts combined, yellow, and red blobs in one image traversal.
  /// Each mask retains independent 4-neighbor connectivity.
  static (List<Blob> combined, List<Blob> yellow, List<Blob> red)
  extractThreeMasks({
    required ColorMask combinedMask,
    required ColorMask yellowMask,
    required ColorMask redMask,
    int minimumPixelCount = 1,
    int? minX,
    int? minY,
    int? maxX,
    int? maxY,
  }) {
    final width = combinedMask.width;
    final height = combinedMask.height;
    if (yellowMask.width != width ||
        yellowMask.height != height ||
        redMask.width != width ||
        redMask.height != height) {
      throw ArgumentError('Mask dimensions must match');
    }

    final masks = [combinedMask, yellowMask, redMask];
    final results = [<Blob>[], <Blob>[], <Blob>[]];

    final startX = (minX ?? 0).clamp(0, width);
    final startY = (minY ?? 0).clamp(0, height);
    final endX = (maxX ?? width).clamp(0, width);
    final endY = (maxY ?? height).clamp(0, height);
    final roiWidth = (endX - startX).clamp(0, width);
    final roiHeight = (endY - startY).clamp(0, height);
    final visited = [
      List<bool>.filled(roiWidth * roiHeight, false),
      List<bool>.filled(roiWidth * roiHeight, false),
      List<bool>.filled(roiWidth * roiHeight, false),
    ];

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final index = y * width + x;

        for (var channel = 0; channel < 3; channel++) {
          final visitedIndex = (y - startY) * roiWidth + (x - startX);
          if (visited[channel][visitedIndex] || !masks[channel].pixels[index]) {
            continue;
          }

          final blob = _extractSingleBlob(
            mask: masks[channel],
            startX: x,
            startY: y,
            visited: visited[channel],
            visitedOriginX: startX,
            visitedOriginY: startY,
            visitedWidth: roiWidth,
            roiMinX: startX,
            roiMinY: startY,
            roiMaxX: endX,
            roiMaxY: endY,
          );

          if (blob.pixelCount >= minimumPixelCount) {
            results[channel].add(blob);
          }
        }
      }
    }

    return (results[0], results[1], results[2]);
  }

  /// Extracts three ROI masks using original-image coordinates.
  static (List<Blob> combined, List<Blob> yellow, List<Blob> red)
  extractThreeRoiMasks({
    required RoiColorMask combinedMask,
    required RoiColorMask yellowMask,
    required RoiColorMask redMask,
    int minimumPixelCount = 1,
  }) {
    final masks = [combinedMask, yellowMask, redMask];
    final originX = combinedMask.originX;
    final originY = combinedMask.originY;
    final width = combinedMask.width;
    final height = combinedMask.height;

    for (final mask in masks) {
      if (mask.originX != originX ||
          mask.originY != originY ||
          mask.width != width ||
          mask.height != height) {
        throw ArgumentError('ROI mask bounds must match');
      }
    }

    final results = [<Blob>[], <Blob>[], <Blob>[]];
    final visited = List.generate(
      3,
      (_) => List<bool>.filled(width * height, false),
    );

    const directions = <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)];

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final startIndex = y * width + x;

        for (var channel = 0; channel < 3; channel++) {
          final pixels = masks[channel].pixels;
          final seen = visited[channel];

          if (seen[startIndex] || !pixels[startIndex]) {
            continue;
          }

          final queue = <int>[startIndex];
          seen[startIndex] = true;
          var queueIndex = 0;

          var pixelCount = 0;
          var sumX = 0;
          var sumY = 0;

          var minX = originX + x;
          var maxX = minX;
          var minY = originY + y;
          var maxY = minY;

          while (queueIndex < queue.length) {
            final index = queue[queueIndex++];
            final localX = index % width;
            final localY = index ~/ width;
            final imageX = originX + localX;
            final imageY = originY + localY;

            pixelCount++;
            sumX += imageX;
            sumY += imageY;

            if (imageX < minX) minX = imageX;
            if (imageX > maxX) maxX = imageX;
            if (imageY < minY) minY = imageY;
            if (imageY > maxY) maxY = imageY;

            for (final direction in directions) {
              final nextX = localX + direction.$1;
              final nextY = localY + direction.$2;

              if (nextX < 0 || nextX >= width || nextY < 0 || nextY >= height) {
                continue;
              }

              final nextIndex = nextY * width + nextX;

              if (seen[nextIndex] || !pixels[nextIndex]) {
                continue;
              }

              seen[nextIndex] = true;
              queue.add(nextIndex);
            }
          }

          if (pixelCount >= minimumPixelCount) {
            results[channel].add(
              Blob(
                pixelCount: pixelCount,
                minX: minX,
                minY: minY,
                maxX: maxX,
                maxY: maxY,
                centroidX: sumX / pixelCount,
                centroidY: sumY / pixelCount,
              ),
            );
          }
        }
      }
    }

    return (results[0], results[1], results[2]);
  }

  const BlobAnalyzer._();

  static List<Blob> extractBlobs(
    ColorMask mask, {
    int minimumPixelCount = 1,
    int? minX,
    int? minY,
    int? maxX,
    int? maxY,
  }) {
    final blobs = <Blob>[];

    final startX = (minX ?? 0).clamp(0, mask.width);
    final startY = (minY ?? 0).clamp(0, mask.height);
    final endX = (maxX ?? mask.width).clamp(0, mask.width);
    final endY = (maxY ?? mask.height).clamp(0, mask.height);
    final roiWidth = (endX - startX).clamp(0, mask.width);
    final roiHeight = (endY - startY).clamp(0, mask.height);
    final visited = List<bool>.filled(roiWidth * roiHeight, false);

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final index = y * mask.width + x;

        final visitedIndex = (y - startY) * roiWidth + (x - startX);
        if (visited[visitedIndex] || !mask.pixels[index]) {
          continue;
        }

        final blob = _extractSingleBlob(
          mask: mask,
          startX: x,
          startY: y,
          visited: visited,
          visitedOriginX: startX,
          visitedOriginY: startY,
          visitedWidth: roiWidth,
          roiMinX: startX,
          roiMinY: startY,
          roiMaxX: endX,
          roiMaxY: endY,
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
    required int visitedOriginX,
    required int visitedOriginY,
    required int visitedWidth,
    int roiMinX = 0,
    int roiMinY = 0,
    int? roiMaxX,
    int? roiMaxY,
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

    visited[(startY - visitedOriginY) * visitedWidth +
            (startX - visitedOriginX)] =
        true;

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

        if (nextX < roiMinX ||
            nextX >= (roiMaxX ?? mask.width) ||
            nextY < roiMinY ||
            nextY >= (roiMaxY ?? mask.height)) {
          continue;
        }

        final nextIndex = nextY * mask.width + nextX;

        final nextVisitedIndex =
            (nextY - visitedOriginY) * visitedWidth + (nextX - visitedOriginX);

        if (visited[nextVisitedIndex] || !mask.pixels[nextIndex]) {
          continue;
        }

        visited[nextVisitedIndex] = true;
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
