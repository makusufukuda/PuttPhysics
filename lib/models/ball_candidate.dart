class BallCandidate {
  const BallCandidate({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.confidence,
  });

  final double centerX;
  final double centerY;
  final double radius;
  final double confidence;

  @override
  String toString() {
    return 'BallCandidate('
        'centerX: $centerX, '
        'centerY: $centerY, '
        'radius: $radius, '
        'confidence: $confidence'
        ')';
  }
}
