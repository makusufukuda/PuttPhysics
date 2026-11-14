import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/putter_candidate.dart';
import '../models/putter_tracking_session.dart';
import '../models/tracked_ball.dart';
import '../models/tracked_putter.dart';
import 'putter_detector.dart';
import 'putter_frame_buffer.dart';
import 'putter_tracker.dart';

class PutterBufferedDetection {
  const PutterBufferedDetection({
    required this.frameIndex,
    required this.timestamp,
    required this.candidates,
  });

  final int frameIndex;
  final Duration timestamp;
  final List<PutterCandidate> candidates;
}

class PutterBallDistance {
  const PutterBallDistance({
    required this.frameIndex,
    required this.timestamp,
    required this.centerDistancePixels,
  });

  final int frameIndex;
  final Duration timestamp;
  final double centerDistancePixels;
}

class PutterBufferAnalyzer {
  const PutterBufferAnalyzer._();

  static PutterFrameSpeed? lastPreMovementSpeed({
    required PutterTrackingSession session,
    required int movementStartFrame,
  }) {
    PutterFrameSpeed? latest;

    for (final speed in session.allFrameSpeeds()) {
      if (speed.currentFrame >= movementStartFrame) {
        continue;
      }

      if (latest == null || speed.currentFrame > latest.currentFrame) {
        latest = speed;
      }
    }

    return latest;
  }

  static List<PutterBallDistance> matchBallPositions({
    required List<TrackedPutter> putters,
    required List<TrackedBall> balls,
  }) {
    final ballsByFrame = {
      for (final ball in balls) ball.frameIndex: ball,
    };

    final results = <PutterBallDistance>[];

    for (final putter in putters) {
      final ball = ballsByFrame[putter.frameIndex];
      if (ball == null) continue;

      if (ball.timestamp != putter.timestamp) {
        debugPrint(
          'PUTTER BALL PTS MISMATCH '
          'frame=${putter.frameIndex} '
          'putterPtsUs=${putter.timestamp.inMicroseconds} '
          'ballPtsUs=${ball.timestamp.inMicroseconds}',
        );
        continue;
      }

      final dx = putter.centerX - ball.centerX;
      final dy = putter.centerY - ball.centerY;

      results.add(
        PutterBallDistance(
          frameIndex: putter.frameIndex,
          timestamp: putter.timestamp,
          centerDistancePixels: math.sqrt(dx * dx + dy * dy),
        ),
      );
    }

    return results;
  }

  static PutterTrackingSession trackDetections(
    List<PutterBufferedDetection> detections,
  ) {
    final tracker = PutterTracker();
    final session = PutterTrackingSession();

    for (final detection in detections) {
      final tracked = tracker.track(
        frameIndex: detection.frameIndex,
        timestamp: detection.timestamp,
        candidates: detection.candidates,
      );

      if (tracked != null) {
        session.add(tracked);
      }
    }

    return session;
  }

  static List<PutterBufferedDetection> analyze(
    PutterFrameBuffer buffer,
  ) {
    final results = <PutterBufferedDetection>[];

    for (final frame in buffer.frames) {
      final localCandidates = PutterDetector.detectDecoded(
        frame.image,
        frameIndex: frame.frameIndex,
      );

      final globalCandidates = [
        for (final candidate in localCandidates)
          PutterCandidate(
            centerX: candidate.centerX + frame.originX,
            centerY: candidate.centerY + frame.originY,
            width: candidate.width,
            height: candidate.height,
            blobCount: candidate.blobCount,
            confidence: candidate.confidence,
          ),
      ];

      results.add(
        PutterBufferedDetection(
          frameIndex: frame.frameIndex,
          timestamp: frame.timestamp,
          candidates: globalCandidates,
        ),
      );
    }

    return results;
  }
}
