import 'package:image/image.dart' as img;

class PutterBufferedFrame {
  const PutterBufferedFrame({
    required this.frameIndex,
    required this.timestamp,
    required this.image,
    required this.originX,
    required this.originY,
  });

  final int frameIndex;
  final Duration timestamp;
  final img.Image image;
  final int originX;
  final int originY;
}

class PutterFrameBuffer {
  PutterFrameBuffer({this.capacity = 8})
      : assert(capacity > 0);

  final int capacity;
  final List<PutterBufferedFrame> _frames = [];

  int get length => _frames.length;

  List<PutterBufferedFrame> get frames =>
      List.unmodifiable(_frames);

  void add({
    required img.Image image,
    required int frameIndex,
    required Duration timestamp,
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
  }) {
    final x1 = minX.clamp(0, image.width);
    final y1 = minY.clamp(0, image.height);
    final x2 = maxX.clamp(0, image.width);
    final y2 = maxY.clamp(0, image.height);

    if (x2 <= x1 || y2 <= y1) {
      return;
    }

    final cropped = img.copyCrop(
      image,
      x: x1,
      y: y1,
      width: x2 - x1,
      height: y2 - y1,
    );

    _frames.add(
      PutterBufferedFrame(
        frameIndex: frameIndex,
        timestamp: timestamp,
        image: cropped,
        originX: x1,
        originY: y1,
      ),
    );

    if (_frames.length > capacity) {
      _frames.removeAt(0);
    }
  }

  void clear() {
    _frames.clear();
  }
}
