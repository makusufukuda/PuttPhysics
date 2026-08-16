class BallCandidate {
  const BallCandidate({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.confidence,
    this.isCombinedRedYellow = false,
    this.isMotionBlur = false,
  });

  final double centerX;
  final double centerY;
  final double radius;
  final double confidence;
  final bool isCombinedRedYellow;
  final bool isMotionBlur;

  @override
  String toString() {
    return 'BallCandidate('
        'centerX: $centerX, '
        'centerY: $centerY, '
        'radius: $radius, '
        'confidence: $confidence, '
        'isCombinedRedYellow: $isCombinedRedYellow, '
        'isMotionBlur: $isMotionBlur'
        ')';
  }
}
