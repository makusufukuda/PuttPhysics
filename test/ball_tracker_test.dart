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

    test('accepts large movement when continuing in the same direction', () {
      final tracker = BallTracker();

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 594.5,
            centerY: 920,
            radius: 25,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final second = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 533.0,
            centerY: 922,
            radius: 25,
            confidence: 0.85,
          ),
        ],
      );

      expect(second, isNotNull);
      expect(second!.centerX, 533.0);

      final third = tracker.track(
        frameIndex: 3,
        timestamp: const Duration(milliseconds: 100),
        candidates: const [
          BallCandidate(
            centerX: 386.5,
            centerY: 927,
            radius: 25,
            confidence: 0.75,
          ),
        ],
      );

      // The ball has already started moving to the left.
      // The next candidate continues in the same direction and is within
      // the extended 160 pixel movement range.
      expect(third, isNotNull);
      expect(third!.centerX, 386.5);
      expect(third.centerY, 927);
    });

    test('prefers forward candidate after high speed movement', () {
      final tracker = BallTracker();

      tracker.track(
        frameIndex: 1,
        timestamp: const Duration(milliseconds: 0),
        candidates: const [
          BallCandidate(
            centerX: 612.5,
            centerY: 920,
            radius: 25,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final moved = tracker.track(
        frameIndex: 2,
        timestamp: const Duration(milliseconds: 50),
        candidates: const [
          BallCandidate(
            centerX: 506.5,
            centerY: 922,
            radius: 25,
            confidence: 0.8,
          ),
        ],
      );

      expect(moved, isNotNull);
      expect(moved!.centerX, 506.5);

      final result = tracker.track(
        frameIndex: 3,
        timestamp: const Duration(milliseconds: 100),
        candidates: const [
          BallCandidate(
            centerX: 506.5,
            centerY: 922,
            radius: 25,
            confidence: 0.95,
          ),
          BallCandidate(
            centerX: 400.5,
            centerY: 924,
            radius: 25,
            confidence: 0.75,
          ),
        ],
      );

      expect(result, isNotNull);

      // Once the ball is moving quickly to the left, the candidate that
      // continues in the same direction should be preferred over a
      // high-confidence candidate left behind at the previous position.
      expect(result!.centerX, 400.5);
      expect(result.centerY, 924);
    });

    test('does not force direction preference after small movement', () {
      final tracker = BallTracker(directionPreferenceThresholdPixels: 60);

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
            centerX: 120,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
          ),
        ],
      );

      final result = tracker.track(
        frameIndex: 3,
        timestamp: const Duration(milliseconds: 100),
        candidates: const [
          BallCandidate(
            centerX: 120,
            centerY: 100,
            radius: 20,
            confidence: 0.95,
          ),
          BallCandidate(
            centerX: 140,
            centerY: 100,
            radius: 20,
            confidence: 0.60,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.centerX, 120);
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

    test('accepts first large launch movement from stationary ball', () {
      final tracker = BallTracker();

      tracker.track(
        frameIndex: 97,
        timestamp: const Duration(milliseconds: 3233),
        candidates: const [
          BallCandidate(
            centerX: 600,
            centerY: 900,
            radius: 25,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final stationary = tracker.track(
        frameIndex: 98,
        timestamp: const Duration(milliseconds: 3266),
        candidates: const [
          BallCandidate(
            centerX: 600,
            centerY: 900,
            radius: 25,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );

      expect(stationary, isNotNull);

      final launched = tracker.track(
        frameIndex: 99,
        timestamp: const Duration(milliseconds: 3300),
        candidates: const [
          BallCandidate(
            centerX: 425,
            centerY: 900,
            radius: 25,
            confidence: 0.85,
            isCombinedRedYellow: true,
          ),
        ],
      );

      // A real ball can move more than the normal 120 px limit
      // on the first frame immediately after launch.
      expect(launched, isNotNull);
      expect(launched!.centerX, 425);
      expect(launched.centerY, 900);
      expect(tracker.missedFrameCount, 0);
    });

    test('accepts radius growth during high speed forward movement', () {
      final tracker = BallTracker();

      tracker.track(
        frameIndex: 76,
        timestamp: const Duration(milliseconds: 3750),
        candidates: const [
          BallCandidate(
            centerX: 471.5,
            centerY: 1045.5,
            radius: 23.0,
            confidence: 0.854,
            isCombinedRedYellow: true,
          ),
        ],
      );

      final firstMove = tracker.track(
        frameIndex: 77,
        timestamp: const Duration(milliseconds: 3800),
        candidates: const [
          BallCandidate(
            centerX: 362.5,
            centerY: 1040.5,
            radius: 19.0,
            confidence: 0.721,
          ),
        ],
      );

      expect(firstMove, isNotNull);

      final secondMove = tracker.track(
        frameIndex: 78,
        timestamp: const Duration(milliseconds: 3850),
        candidates: const [
          BallCandidate(
            centerX: 287.5,
            centerY: 1038.5,
            radius: 16.5,
            confidence: 0.473,
          ),
        ],
      );

      expect(secondMove, isNotNull);

      final thirdMove = tracker.track(
        frameIndex: 79,
        timestamp: const Duration(milliseconds: 3900),
        candidates: const [
          BallCandidate(
            centerX: 147.5,
            centerY: 1050.5,
            radius: 25.5,
            confidence: 0.70,
          ),
        ],
      );

      // During high-speed forward movement, a real ball candidate can
      // temporarily change apparent radius because of blur / shape changes.
      expect(thirdMove, isNotNull);
      expect(thirdMove!.centerX, 147.5);
      expect(thirdMove.centerY, 1050.5);
      expect(tracker.missedFrameCount, 0);
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
