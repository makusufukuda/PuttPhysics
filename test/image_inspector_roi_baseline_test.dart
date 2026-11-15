import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/frame_extractor.dart';
import 'package:putt_physics_v1/services/image_inspector.dart';

void main() {
  test('ImageInspector preserves full-frame metadata with ROI', () {
    const width = 240;
    const height = 180;

    final bytes = Uint8List(width * height * 4);

    // Blue background in BGRA format.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Red 40 x 40 region inside ROI.
    for (var y = 50; y < 90; y++) {
      for (var x = 50; x < 90; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = 0;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final image = FrameExtractor.decodeFrame(frame)!;

    final result = ImageInspector.inspectDecoded(
      image,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    expect(result.width, width);
    expect(result.height, height);
    expect(result.centerX, 120);
    expect(result.centerY, 90);

    expect(result.centerRed, 0);
    expect(result.centerGreen, 0);
    expect(result.centerBlue, 255);

    expect(result.totalPixels, width * height);
    expect(result.redPixels, 1600);
    expect(result.yellowPixels, 0);

    expect(result.ballCandidateCount, greaterThan(0));
    expect(result.bestBallCandidate, isNotNull);

    final ball = result.bestBallCandidate!;
    expect(ball.centerX, closeTo(69.5, 0.001));
    expect(ball.centerY, closeTo(69.5, 0.001));
    expect(ball.radius, closeTo(20, 0.001));

    expect(result.targetColorPixels, 1600);
    expect(result.redRatio, closeTo(1600 / (width * height), 1e-10));
    expect(result.yellowRatio, 0);

    expect(result.blobCount, greaterThan(0));
    expect(result.largestBlob, isNotNull);

    final blob = result.largestBlob!;
    expect(blob.pixelCount, 1600);
    expect(blob.minX, 50);
    expect(blob.minY, 50);
    expect(blob.maxX, 89);
    expect(blob.maxY, 89);
    expect(blob.centroidX, closeTo(69.5, 0.001));
    expect(blob.centroidY, closeTo(69.5, 0.001));

    expect(ball.confidence, closeTo(1.0, 0.001));
    expect(ball.isMotionBlur, isFalse);
    expect(ball.isCombinedRedYellow, isFalse);
  });
}
