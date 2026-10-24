import 'package:flutter/material.dart';

class InitialBallSearchRegion {
  const InitialBallSearchRegion._();

  static bool contains({
    required Map<String, Offset> markers,
    required Offset point,
  }) {
    final topLeft = markers['topLeft'];
    final topRight = markers['topRight'];
    final bottomLeft = markers['bottomLeft'];
    final bottomRight = markers['bottomRight'];

    if (topLeft == null ||
        topRight == null ||
        bottomLeft == null ||
        bottomRight == null) {
      return false;
    }

    final middleLeft = Offset(
      (topLeft.dx + bottomLeft.dx) / 2,
      (topLeft.dy + bottomLeft.dy) / 2,
    );

    final middleRight = Offset(
      (topRight.dx + bottomRight.dx) / 2,
      (topRight.dy + bottomRight.dy) / 2,
    );

    final polygon = [
      middleLeft,
      middleRight,
      bottomRight,
      bottomLeft,
    ];

    var inside = false;

    for (var i = 0, j = polygon.length - 1;
        i < polygon.length;
        j = i++) {
      final a = polygon[i];
      final b = polygon[j];

      final intersects =
          ((a.dy > point.dy) != (b.dy > point.dy)) &&
          (point.dx <
              (b.dx - a.dx) *
                      (point.dy - a.dy) /
                      (b.dy - a.dy) +
                  a.dx);

      if (intersects) {
        inside = !inside;
      }
    }

    return inside;
  }
}
