import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/ball_candidate.dart';
import 'package:putt_physics_v1/services/ball_tracker.dart';

void main() {
  group('BallTracker', () {
    test('selects combined red-yellow candidate initially', () {
      final tracker = BallTracker();

      final result = tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.95,
          ),
          BallCandidate(
            centerX: 200,
            centerY: 200,
            radius: 20,
            confidence: 0.80,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.centerX, 200);
      expect(result.centerY, 200);
    });

    test('preserves motion blur candidate flag', () {
      final tracker = BallTracker();

      final result = tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isMotionBlur: true,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.centerX, 100);
      expect(result.centerY, 100);
    });

    test('tracks nearby candidate', () {
      final tracker = BallTracker();

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 140,
            centerY: 105,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.centerX, 140);
      expect(result.centerY, 105);
    });

    test('tracks motion blur candidate after normal ball movement', () {
      final tracker = BallTracker();

      final first = tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 11,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(first, isNotNull);

      final second = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 140,
            centerY: 100,
            radius: 11,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(second, isNotNull);

      final blurred = tracker.track(
        frameIndex: 3,
        timestamp: const Duration(milliseconds: 100),
        candidates: const [
          BallCandidate(
            centerX: 190,
            centerY: 100,
            radius: 11,
            confidence: 0.6,
            isMotionBlur: true,
          ),
        ],
      );

      expect(blurred, isNotNull);
      expect(blurred!.frameIndex, 3);
      expect(blurred.centerX, 190);
      expect(blurred.centerY, 100);
      expect(tracker.missedFrameCount, 0);
    });

    test(
      'accepts normal candidate beyond normal limit when prediction is strong',
      () {
        final tracker = BallTracker(
          maximumMovementPixels: 120,
          maximumPredictedMovementPixels: 160,
          minimumPredictionScoreForExtendedMovement: 0.70,
        );

        tracker.track(
          frameIndex: 1,
          timestamp: const Duration(milliseconds: 0),
          candidates: const [
            BallCandidate(
              centerX: 100,
              centerY: 100,
              radius: 20,
              confidence: 0.9,
              isCombinedRedYellow: true,
            ),
          ],
        );

        tracker.track(
          frameIndex: 2,
          timestamp: const Duration(milliseconds: 100),
          candidates: const [
            BallCandidate(
              centerX: 150,
              centerY: 100,
              radius: 20,
              confidence: 0.9,
              isCombinedRedYellow: true,
            ),
          ],
        );

        final result = tracker.track(
          frameIndex: 3,
          timestamp: const Duration(milliseconds: 350),
          candidates: const [
            BallCandidate(
              centerX: 275,
              centerY: 100,
              radius: 20,
              confidence: 0.8,
            ),
          ],
        );

        expect(result, isNotNull);
        expect(result!.centerX, 275);
        expect(result.centerY, 100);
      },
    );

    test(
      'rejects normal candidate beyond normal limit when prediction is weak',
      () {
        final tracker = BallTracker(
          maximumMovementPixels: 120,
          maximumPredictedMovementPixels: 160,
          minimumPredictionScoreForExtendedMovement: 0.70,
        );

        tracker.track(
          frameIndex: 1,
          timestamp: const Duration(milliseconds: 0),
          candidates: const [
            BallCandidate(
              centerX: 100,
              centerY: 100,
              radius: 20,
              confidence: 0.9,
              isCombinedRedYellow: true,
            ),
          ],
        );

        tracker.track(
          frameIndex: 2,
          timestamp: const Duration(milliseconds: 50),
          candidates: const [
            BallCandidate(
              centerX: 150,
              centerY: 100,
              radius: 20,
              confidence: 0.9,
              isCombinedRedYellow: true,
            ),
          ],
        );

        final result = tracker.track(
          frameIndex: 3,
          timestamp: const Duration(milliseconds: 100),
          candidates: const [
            BallCandidate(
              centerX: 150,
              centerY: 225,
              radius: 20,
              confidence: 0.8,
            ),
          ],
        );

        expect(result, isNull);
        expect(tracker.missedFrameCount, 1);
      },
    );

    test('still rejects normal candidate beyond predicted movement limit', () {
      final tracker = BallTracker(
        maximumMovementPixels: 120,
        maximumPredictedMovementPixels: 160,
        minimumPredictionScoreForExtendedMovement: 0.70,
      );

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 150,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 3,
        timestamp: const Duration(milliseconds: 100),
        candidates: const [
          BallCandidate(
            centerX: 320,
            centerY: 100,
            radius: 20,
            confidence: 0.8,
          ),
        ],
      );

      expect(result, isNull);
      expect(tracker.missedFrameCount, 1);
    });

    test('accepts motion blur candidate beyond normal movement limit', () {
      final tracker = BallTracker(
        maximumMovementPixels: 120,
        maximumMotionBlurMovementPixels: 300,
      );

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 320,
            centerY: 100,
            radius: 20,
            confidence: 0.6,
            isMotionBlur: true,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.centerX, 320);
      expect(result.centerY, 100);
      expect(tracker.missedFrameCount, 0);
    });

    test('keeps normal candidate limited to normal movement distance', () {
      final tracker = BallTracker(
        maximumMovementPixels: 120,
        maximumMotionBlurMovementPixels: 300,
      );

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 320,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
          ),
        ],
      );

      expect(result, isNull);
      expect(tracker.missedFrameCount, 1);
    });

    test('rejects motion blur candidate beyond motion blur movement limit', () {
      final tracker = BallTracker(
        maximumMovementPixels: 120,
        maximumMotionBlurMovementPixels: 300,
      );

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 450,
            centerY: 100,
            radius: 20,
            confidence: 0.6,
            isMotionBlur: true,
          ),
        ],
      );

      expect(result, isNull);
      expect(tracker.missedFrameCount, 1);
    });

    test('rejects distant motion blur candidate', () {
      final tracker = BallTracker();

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 11,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 140,
            centerY: 100,
            radius: 11,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 3,
        timestamp: const Duration(milliseconds: 100),
        candidates: const [
          BallCandidate(
            centerX: 450,
            centerY: 100,
            radius: 11,
            confidence: 0.6,
            isMotionBlur: true,
          ),
        ],
      );

      expect(result, isNull);
      expect(tracker.missedFrameCount, 1);
    });

    test('rejects candidate beyond maximum movement', () {
      final tracker = BallTracker(maximumMovementPixels: 120);

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 300,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(result, isNull);
      expect(tracker.missedFrameCount, 1);
    });

    test('ends tracking after repeated misses once movement started', () {
      final tracker = BallTracker(
        maximumMissedFrames: 3,
        movementStartThresholdPixels: 20,
      );

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 100,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 130,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      for (var i = 0; i < 4; i++) {
        tracker.track(
          frameIndex: 3 + i,
          timestamp: Duration(milliseconds: 100 + (i * 50)),
          candidates: const [],
        );
      }

      final result = tracker.track(
        frameIndex: 7,
        timestamp: const Duration(milliseconds: 300),
        candidates: const [
          BallCandidate(
            centerX: 140,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(result, isNull);
    });
  });
}
