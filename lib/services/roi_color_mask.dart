class RoiColorMask {
  RoiColorMask({
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
  }) : pixels = List<bool>.filled(width * height, false);

  final int originX;
  final int originY;
  final int width;
  final int height;
  final List<bool> pixels;

  bool contains(int x, int y) {
    return x >= originX &&
        x < originX + width &&
        y >= originY &&
        y < originY + height;
  }

  bool getPixel(int x, int y) {
    if (!contains(x, y)) return false;
    return pixels[(y - originY) * width + (x - originX)];
  }

  void setPixel(int x, int y, bool value) {
    if (!contains(x, y)) {
      throw RangeError('Pixel outside ROI: ($x, $y)');
    }
    pixels[(y - originY) * width + (x - originX)] = value;
  }
}
