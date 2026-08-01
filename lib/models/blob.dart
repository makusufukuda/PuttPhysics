class Blob {
  const Blob({
    required this.pixelCount,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.centroidX,
    required this.centroidY,
  });

  final int pixelCount;

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  final double centroidX;
  final double centroidY;

  int get width => maxX - minX + 1;

  int get height => maxY - minY + 1;

  int get boundingBoxArea => width * height;

  double get fillRatio {
    if (boundingBoxArea == 0) {
      return 0;
    }

    return pixelCount / boundingBoxArea;
  }

  @override
  String toString() {
    return 'Blob('
        'pixelCount: $pixelCount, '
        'bounds: ($minX, $minY)-($maxX, $maxY), '
        'centroid: '
        '(${centroidX.toStringAsFixed(1)}, '
        '${centroidY.toStringAsFixed(1)}), '
        'fillRatio: ${fillRatio.toStringAsFixed(3)}'
        ')';
  }
}
