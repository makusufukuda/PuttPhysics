class ColorMask {
  ColorMask({required this.width, required this.height})
    : pixels = List<bool>.filled(width * height, false);

  final int width;
  final int height;

  final List<bool> pixels;

  bool getPixel(int x, int y) {
    return pixels[y * width + x];
  }

  void setPixel(int x, int y, bool value) {
    pixels[y * width + x] = value;
  }
}
