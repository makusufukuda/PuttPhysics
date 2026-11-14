import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:putt_physics_v1/models/putter_candidate.dart';
import 'package:putt_physics_v1/services/putter_buffer_analyzer.dart';
import 'package:putt_physics_v1/services/putter_frame_buffer.dart';

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
}
