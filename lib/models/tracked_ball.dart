class TrackedBall {
  const TrackedBall({
    required this.frameIndex,
    required this.timestamp,
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.confidence,
  });

  final int frameIndex;
  final Duration timestamp;
  final double centerX;
  final double centerY;
  final double radius;
  final double confidence;

  @override
  String toString() {
    return 'TrackedBall('
        'frameIndex: $frameIndex, '
        'timestamp: ${timestamp.inMilliseconds}ms, '
        'centerX: $centerX, '
        'centerY: $centerY, '
        'radius: $radius, '
        'confidence: $confidence'
        ')';
  }
}
