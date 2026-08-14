enum MarkerPosition { topLeft, topRight, bottomLeft, bottomRight }

class MarkerCandidate {
  const MarkerCandidate({
    required this.position,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.pixelCount,
  });

  final MarkerPosition position;
  final double centerX;
  final double centerY;
  final int width;
  final int height;
  final int pixelCount;

  @override
  String toString() {
    return 'MarkerCandidate('
        'position: $position, '
        'centerX: ${centerX.toStringAsFixed(1)}, '
        'centerY: ${centerY.toStringAsFixed(1)}, '
        'width: $width, '
        'height: $height, '
        'pixelCount: $pixelCount'
        ')';
  }
}
