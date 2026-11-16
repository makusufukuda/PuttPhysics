import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/models/ball_candidate.dart';
import 'package:putt_physics_v1/services/ball_tracker.dart';

void main() {
  test('records first movement frame after confirmation', () {
    final tracker = BallTracker();

    void track(int frame, double x) {
      tracker.track(
        frameIndex: frame,
        timestamp: Duration(milliseconds: frame * 10),
        candidates: [
          BallCandidate(
            centerX: x,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );
    }

    track(10, 100);
    expect(tracker.pendingMovementStartFrame, isNull);
    expect(tracker.movementStartFrame, isNull);

    track(11, 130);
    expect(tracker.movementPending, isTrue);
    expect(tracker.pendingMovementStartFrame, 11);
    expect(tracker.movementStartFrame, isNull);

    track(12, 160);
    expect(tracker.movementStarted, isTrue);
    expect(tracker.pendingMovementStartFrame, isNull);
    expect(tracker.movementStartFrame, 11);

    tracker.reset();
    expect(tracker.movementStarted, isFalse);
    expect(tracker.pendingMovementStartFrame, isNull);
    expect(tracker.movementStartFrame, isNull);
  });

  test('clears pending frame when movement stops', () {
    final tracker = BallTracker();

    void track(int frame, double x) {
      tracker.track(
        frameIndex: frame,
        timestamp: Duration(milliseconds: frame * 10),
        candidates: [
          BallCandidate(
            centerX: x,
            centerY: 100,
            radius: 20,
            confidence: 0.9,
            isCombinedRedYellow: true,
          ),
        ],
      );
    }

    track(20, 100);
    track(21, 130);
    expect(tracker.pendingMovementStartFrame, 21);

    track(22, 131);
    expect(tracker.movementStarted, isFalse);
    expect(tracker.pendingMovementStartFrame, isNull);
    expect(tracker.movementStartFrame, isNull);
  });
}
