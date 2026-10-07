class PutterCandidate {
  const PutterCandidate({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.blobCount,
    required this.confidence,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final int blobCount;
  final double confidence;

  bool get isBlobPair => blobCount == 2;

  @override
  String toString() {
    return 'PutterCandidate('
        'centerX: $centerX, '
        'centerY: $centerY, '
        'width: $width, '
        'height: $height, '
        'blobCount: $blobCount, '
        'confidence: $confidence'
        ')';
  }
}
