class TrackedPutter {
  const TrackedPutter({
    required this.frameIndex,
    required this.timestamp,
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.confidence,
  });

  final int frameIndex;
  final Duration timestamp;
  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double confidence;
}
