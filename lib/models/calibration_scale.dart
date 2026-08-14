class CalibrationScale {
  const CalibrationScale({
    required this.referenceDistanceMillimeters,
    required this.referenceDistancePixels,
  });

  final double referenceDistanceMillimeters;
  final double referenceDistancePixels;

  double get pixelsPerMillimeter =>
      referenceDistancePixels / referenceDistanceMillimeters;

  double pixelsToMillimeters(double pixels) {
    return pixels / pixelsPerMillimeter;
  }

  double pixelsPerSecondToMillimetersPerSecond(double pixelsPerSecond) {
    return pixelsPerSecond / pixelsPerMillimeter;
  }

  double pixelsPerSecondToMetersPerSecond(double pixelsPerSecond) {
    return pixelsPerSecondToMillimetersPerSecond(pixelsPerSecond) / 1000.0;
  }

  bool get isValid =>
      referenceDistanceMillimeters > 0 && referenceDistancePixels > 0;
}
