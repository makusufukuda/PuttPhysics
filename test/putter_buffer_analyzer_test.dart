import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/models/putter_candidate.dart';
import 'package:putt_physics_v1/services/putter_buffer_analyzer.dart';
import 'package:putt_physics_v1/services/putter_frame_buffer.dart';
import 'package:putt_physics_v1/services/frame_extractor.dart';

import 'package:putt_physics_v1/models/tracked_ball.dart';
import 'package:putt_physics_v1/models/tracked_putter.dart';
import 'package:putt_physics_v1/models/putter_tracking_session.dart';

void main() {
  test('移動開始フレームを除外して直前の速度を選択する', () {
    final session = PutterTrackingSession();

    for (final entry in <(int, double)>[
      (100, 100),
      (101, 110),
      (102, 120),
      (103, 150),
    ]) {
      session.add(
        TrackedPutter(
          frameIndex: entry.$1,
          timestamp: Duration(milliseconds: (entry.$1 - 100) * 10),
          centerX: entry.$2,
          centerY: 200,
          width: 60,
          height: 20,
          confidence: 0.9,
        ),
      );
    }

    final result = PutterBufferAnalyzer.lastPreMovementSpeed(
      session: session,
      movementStartFrame: 103,
    );

    expect(result, isNotNull);
    expect(result!.previousFrame, 101);
    expect(result.currentFrame, 102);
    expect(result.speedPixelsPerSecond, closeTo(1000, 0.001));
  });

  test('PTSが異なる場合は距離計算から除外する', () {
    final putters = [
      TrackedPutter(
        frameIndex: 200,
        timestamp: const Duration(milliseconds: 1000),
        centerX: 130,
        centerY: 240,
        width: 60,
        height: 20,
        confidence: 0.9,
      ),
    ];

    final balls = [
      TrackedBall(
        frameIndex: 200,
        timestamp: const Duration(milliseconds: 1010),
        centerX: 100,
        centerY: 200,
        radius: 15,
        confidence: 0.9,
      ),
    ];

    final results = PutterBufferAnalyzer.matchBallPositions(
      putters: putters,
      balls: balls,
    );

    expect(results, isEmpty);
  });

  test('同じフレームのボールとパターの中心間距離を計算する', () {
    final putters = [
      TrackedPutter(
        frameIndex: 100,
        timestamp: const Duration(milliseconds: 1000),
        centerX: 130,
        centerY: 240,
        width: 60,
        height: 20,
        confidence: 0.9,
      ),
      TrackedPutter(
        frameIndex: 101,
        timestamp: const Duration(milliseconds: 1010),
        centerX: 140,
        centerY: 240,
        width: 60,
        height: 20,
        confidence: 0.9,
      ),
    ];

    final balls = [
      TrackedBall(
        frameIndex: 100,
        timestamp: const Duration(milliseconds: 1000),
        centerX: 100,
        centerY: 200,
        radius: 15,
        confidence: 0.9,
      ),
    ];

    final results = PutterBufferAnalyzer.matchBallPositions(
      putters: putters,
      balls: balls,
    );

    expect(results.length, 1);
    expect(results.single.frameIndex, 100);
    expect(results.single.centerDistancePixels, closeTo(50, 0.001));
  });

  test('連続3フレームを追跡してPTSから速度を計算する', () {
    PutterCandidate candidate(double x, double confidence) {
      return PutterCandidate(
        centerX: x,
        centerY: 200,
        width: 60,
        height: 20,
        blobCount: 2,
        confidence: confidence,
      );
    }

    final detections = [
      PutterBufferedDetection(
        frameIndex: 100,
        timestamp: const Duration(milliseconds: 1000),
        candidates: [candidate(100, 0.9)],
      ),
      PutterBufferedDetection(
        frameIndex: 101,
        timestamp: const Duration(milliseconds: 1010),
        candidates: [
          candidate(110, 0.8),
          candidate(300, 0.95),
        ],
      ),
      PutterBufferedDetection(
        frameIndex: 102,
        timestamp: const Duration(milliseconds: 1020),
        candidates: [candidate(120, 0.9)],
      ),
    ];

    final session = PutterBufferAnalyzer.trackDetections(detections);
    final speeds = session.allFrameSpeeds();

    expect(session.length, 3);
    expect(session.putters.map((p) => p.centerX).toList(), [
      100.0,
      110.0,
      120.0,
    ]);
    expect(speeds.length, 2);
    expect(speeds[0].speedPixelsPerSecond, closeTo(1000, 0.01));
    expect(speeds[1].speedPixelsPerSecond, closeTo(1000, 0.01));
  });

  test('ROI座標を元画像座標に変換する', () {
    final image = img.Image(width: 300, height: 300);

    final pink = img.ColorRgb8(255, 0, 150);

    img.fillRect(
      image,
      x1: 100,
      y1: 150,
      x2: 119,
      y2: 169,
      color: pink,
    );

    img.fillRect(
      image,
      x1: 160,
      y1: 150,
      x2: 179,
      y2: 169,
      color: pink,
    );

    final buffer = PutterFrameBuffer();

    buffer.add(
      image: image,
      frameIndex: 370,
      timestamp: const Duration(microseconds: 3083333),
      minX: 80,
      minY: 120,
      maxX: 220,
      maxY: 220,
    );

    final results = PutterBufferAnalyzer.analyze(buffer);

    expect(results.length, 1);
    expect(results.single.frameIndex, 370);
    expect(
      results.single.timestamp.inMicroseconds,
      3083333,
    );

    expect(results.single.candidates, isNotEmpty);

    final candidate = results.single.candidates.first;

    expect(candidate.centerX, closeTo(139.5, 1.0));
    expect(candidate.centerY, closeTo(159.5, 1.0));
    expect(candidate.blobCount, 2);
  });

  test('パターが検出できなくてもフレーム情報を保持する', () {
    final image = img.Image(width: 100, height: 100);
    final buffer = PutterFrameBuffer();

    buffer.add(
      image: image,
      frameIndex: 371,
      timestamp: const Duration(microseconds: 3091667),
      minX: 10,
      minY: 20,
      maxX: 90,
      maxY: 90,
    );

    final results = PutterBufferAnalyzer.analyze(buffer);

    expect(results.length, 1);
    expect(results.single.frameIndex, 371);
    expect(results.single.candidates, isEmpty);
  });

  test('BGRA direct ROI preserves putter detection', () {
    const width = 300;
    const height = 300;
    final bytes = Uint8List(width * height * 4);

    // Two pink markers, matching the existing detector test.
    for (final startX in [100, 160]) {
      for (var y = 150; y < 170; y++) {
        for (var x = startX; x < startX + 20; x++) {
          final offset = (y * width + x) * 4;
          bytes[offset] = 150;     // B
          bytes[offset + 1] = 0;   // G
          bytes[offset + 2] = 255; // R
          bytes[offset + 3] = 255; // A
        }
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(microseconds: 3083333),
      frameIndex: 370,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final original = PutterFrameBuffer();
    final direct = PutterFrameBuffer();

    final full = FrameExtractor.decodeFrame(frame)!;

    original.add(
      image: full,
      frameIndex: 370,
      timestamp: frame.position,
      minX: 80,
      minY: 120,
      maxX: 220,
      maxY: 220,
    );

    final roi = FrameExtractor.decodeFrameRoi(
      frame,
      minX: 80,
      minY: 120,
      maxX: 220,
      maxY: 220,
    )!;

    direct.addCropped(
      image: roi,
      frameIndex: 370,
      timestamp: frame.position,
      originX: 80,
      originY: 120,
    );

    final expected = PutterBufferAnalyzer.analyze(original).single;
    final actual = PutterBufferAnalyzer.analyze(direct).single;

    expect(actual.frameIndex, expected.frameIndex);
    expect(actual.timestamp, expected.timestamp);
    expect(expected.candidates, isNotEmpty);
    expect(actual.candidates.length, expected.candidates.length);

    for (var i = 0; i < expected.candidates.length; i++) {
      final a = actual.candidates[i];
      final e = expected.candidates[i];

      expect(a.centerX, closeTo(e.centerX, 0.001));
      expect(a.centerY, closeTo(e.centerY, 0.001));
      expect(a.width, e.width);
      expect(a.height, e.height);
      expect(a.blobCount, e.blobCount);
      expect(a.confidence, closeTo(e.confidence, 0.000001));
    }
  });


  test('BGRA ROI preserves 120fps putter tracking and speed', () {
    const width = 300;
    const height = 300;

    final original = PutterFrameBuffer();
    final direct = PutterFrameBuffer();

    for (var i = 0; i < 4; i++) {
      final bytes = Uint8List(width * height * 4);
      final shiftX = i * 5;

      for (final startX in [100 + shiftX, 160 + shiftX]) {
        for (var y = 150; y < 170; y++) {
          for (var x = startX; x < startX + 20; x++) {
            final offset = (y * width + x) * 4;
            bytes[offset] = 150;
            bytes[offset + 1] = 0;
            bytes[offset + 2] = 255;
            bytes[offset + 3] = 255;
          }
        }
      }

      final frame = ExtractedVideoFrame(
        position: Duration(microseconds: i * 8333),
        frameIndex: 370 + i,
        imageBytes: bytes,
        pixelFormat: 'BGRA8888',
        width: width,
        height: height,
        bytesPerRow: width * 4,
      );

      original.add(
        image: FrameExtractor.decodeFrame(frame)!,
        frameIndex: frame.frameIndex!,
        timestamp: frame.position,
        minX: 80,
        minY: 120,
        maxX: 240,
        maxY: 220,
      );

      direct.addCropped(
        image: FrameExtractor.decodeFrameRoi(
          frame,
          minX: 80,
          minY: 120,
          maxX: 240,
          maxY: 220,
        )!,
        frameIndex: frame.frameIndex!,
        timestamp: frame.position,
        originX: 80,
        originY: 120,
      );
    }

    final oldDetections = PutterBufferAnalyzer.analyze(original);
    final newDetections = PutterBufferAnalyzer.analyze(direct);

    expect(oldDetections.length, 4);
    expect(newDetections.length, 4);

    for (var i = 0; i < 4; i++) {
      final oldFrame = oldDetections[i];
      final newFrame = newDetections[i];

      expect(newFrame.frameIndex, oldFrame.frameIndex);
      expect(newFrame.timestamp, oldFrame.timestamp);
      expect(oldFrame.candidates, isNotEmpty);
      expect(newFrame.candidates.length, oldFrame.candidates.length);

      for (var j = 0; j < oldFrame.candidates.length; j++) {
        final a = newFrame.candidates[j];
        final e = oldFrame.candidates[j];

        expect(a.centerX, closeTo(e.centerX, 0.001));
        expect(a.centerY, closeTo(e.centerY, 0.001));
        expect(a.confidence, closeTo(e.confidence, 0.000001));
      }
    }

    final oldSession =
        PutterBufferAnalyzer.trackDetections(oldDetections);
    final newSession =
        PutterBufferAnalyzer.trackDetections(newDetections);

    expect(oldSession.length, 4);
    expect(newSession.length, oldSession.length);

    for (var i = 0; i < oldSession.length; i++) {
      final a = newSession.putters[i];
      final e = oldSession.putters[i];

      expect(a.frameIndex, e.frameIndex);
      expect(a.timestamp, e.timestamp);
      expect(a.centerX, closeTo(e.centerX, 0.001));
      expect(a.centerY, closeTo(e.centerY, 0.001));
    }

    final oldSpeeds = oldSession.allFrameSpeeds();
    final newSpeeds = newSession.allFrameSpeeds();

    expect(oldSpeeds.length, 3);
    expect(newSpeeds.length, oldSpeeds.length);

    for (var i = 0; i < oldSpeeds.length; i++) {
      expect(newSpeeds[i].previousFrame, oldSpeeds[i].previousFrame);
      expect(newSpeeds[i].currentFrame, oldSpeeds[i].currentFrame);
      expect(
        newSpeeds[i].speedPixelsPerSecond,
        closeTo(oldSpeeds[i].speedPixelsPerSecond, 0.001),
      );
    }

    final oldPre = PutterBufferAnalyzer.lastPreMovementSpeed(
      session: oldSession,
      movementStartFrame: 374,
    );
    final newPre = PutterBufferAnalyzer.lastPreMovementSpeed(
      session: newSession,
      movementStartFrame: 374,
    );

    expect(oldPre, isNotNull);
    expect(newPre, isNotNull);
    expect(newPre!.previousFrame, oldPre!.previousFrame);
    expect(newPre.currentFrame, oldPre.currentFrame);
    expect(
      newPre.speedPixelsPerSecond,
      closeTo(oldPre.speedPixelsPerSecond, 0.001),
    );
  });

}
