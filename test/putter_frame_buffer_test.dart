import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/services/putter_frame_buffer.dart';

void main() {
  test('最大8フレームを保持する', () {
    final buffer = PutterFrameBuffer();
    final image = img.Image(width: 100, height: 100);

    for (var i = 0; i < 8; i++) {
      buffer.add(
        image: image,
        frameIndex: i,
        timestamp: Duration(microseconds: i * 8333),
        minX: 10,
        minY: 20,
        maxX: 60,
        maxY: 70,
      );
    }

    expect(buffer.length, 8);
    expect(buffer.frames.first.frameIndex, 0);
    expect(buffer.frames.last.frameIndex, 7);
  });

  test('9フレーム目で最古のフレームを削除する', () {
    final buffer = PutterFrameBuffer();
    final image = img.Image(width: 100, height: 100);

    for (var i = 0; i < 9; i++) {
      buffer.add(
        image: image,
        frameIndex: i,
        timestamp: Duration(microseconds: i * 8333),
        minX: 10,
        minY: 20,
        maxX: 60,
        maxY: 70,
      );
    }

    expect(buffer.length, 8);
    expect(buffer.frames.first.frameIndex, 1);
    expect(buffer.frames.last.frameIndex, 8);
  });

  test('ROI画像と元座標と時刻を保持する', () {
    final buffer = PutterFrameBuffer();
    final image = img.Image(width: 100, height: 100);

    buffer.add(
      image: image,
      frameIndex: 371,
      timestamp: const Duration(microseconds: 3091667),
      minX: 10,
      minY: 20,
      maxX: 60,
      maxY: 70,
    );

    final frame = buffer.frames.single;

    expect(frame.image.width, 50);
    expect(frame.image.height, 50);
    expect(frame.originX, 10);
    expect(frame.originY, 20);
    expect(frame.frameIndex, 371);
    expect(frame.timestamp.inMicroseconds, 3091667);
  });

  test('clearで保存フレームを消去する', () {
    final buffer = PutterFrameBuffer();
    final image = img.Image(width: 100, height: 100);

    buffer.add(
      image: image,
      frameIndex: 1,
      timestamp: Duration.zero,
      minX: 0,
      minY: 0,
      maxX: 50,
      maxY: 50,
    );

    buffer.clear();

    expect(buffer.length, 0);
    expect(buffer.frames, isEmpty);
  });

  test('addCropped preserves image pixels and metadata', () {
    final image = img.Image(width: 100, height: 100);

    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 100; x++) {
        image.setPixelRgba(x, y, x, y, (x + y) % 256, 255);
      }
    }

    final original = PutterFrameBuffer();
    final direct = PutterFrameBuffer();

    const timestamp = Duration(microseconds: 3091667);

    original.add(
      image: image,
      frameIndex: 371,
      timestamp: timestamp,
      minX: 10,
      minY: 20,
      maxX: 60,
      maxY: 70,
    );

    final roi = img.copyCrop(
      image,
      x: 10,
      y: 20,
      width: 50,
      height: 50,
    );

    direct.addCropped(
      image: roi,
      frameIndex: 371,
      timestamp: timestamp,
      originX: 10,
      originY: 20,
    );

    final expected = original.frames.single;
    final actual = direct.frames.single;

    expect(actual.image.width, expected.image.width);
    expect(actual.image.height, expected.image.height);
    expect(actual.originX, expected.originX);
    expect(actual.originY, expected.originY);
    expect(actual.frameIndex, expected.frameIndex);
    expect(actual.timestamp, expected.timestamp);

    for (var y = 0; y < actual.image.height; y++) {
      for (var x = 0; x < actual.image.width; x++) {
        final a = actual.image.getPixel(x, y);
        final e = expected.image.getPixel(x, y);

        expect(a.r, e.r);
        expect(a.g, e.g);
        expect(a.b, e.b);
        expect(a.a, e.a);
      }
    }
  });

  test('addCropped keeps the newest eight frames', () {
    final buffer = PutterFrameBuffer();
    final image = img.Image(width: 10, height: 10);

    for (var i = 0; i < 9; i++) {
      buffer.addCropped(
        image: image,
        frameIndex: i,
        timestamp: Duration(microseconds: i * 8333),
        originX: 20,
        originY: 30,
      );
    }

    expect(buffer.length, 8);
    expect(buffer.frames.first.frameIndex, 1);
    expect(buffer.frames.last.frameIndex, 8);
    expect(buffer.frames.last.originX, 20);
    expect(buffer.frames.last.originY, 30);
  });

}
