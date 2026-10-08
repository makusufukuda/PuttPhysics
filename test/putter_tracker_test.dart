import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/models/putter_candidate.dart';
import 'package:putt_physics_v1/services/putter_tracker.dart';

void main() {
  test('tracks putter movement across frames', () {
    final tracker = PutterTracker();
    const candidate = PutterCandidate(
      centerX: 100, centerY: 200, width: 80,
      height: 20, blobCount: 2, confidence: 0.95,
    );
    final first = tracker.track(
      frameIndex: 1, timestamp: Duration.zero,
      candidates: [candidate],
    );
    expect(first?.centerX, 100);
    final second = tracker.track(
      frameIndex: 2,
      timestamp: const Duration(milliseconds: 17),
      candidates: const [PutterCandidate(
        centerX: 110, centerY: 200, width: 80,
        height: 20, blobCount: 2, confidence: 0.95,
      )],
    );
    expect(second?.centerX, 110);
    expect(second?.timestamp.inMilliseconds, 17);
  });

  test("preserves position after a missed frame", () {
    final tracker = PutterTracker();

    tracker.track(
      frameIndex: 1,
      timestamp: Duration.zero,
      candidates: const [
        PutterCandidate(
          centerX: 100, centerY: 200,
          width: 80, height: 20,
          blobCount: 2, confidence: 0.95,
        ),
      ],
    );

    final missed = tracker.track(
      frameIndex: 2,
      timestamp: const Duration(milliseconds: 17),
      candidates: const [],
    );

    expect(missed, isNull);

    final recovered = tracker.track(
      frameIndex: 3,
      timestamp: const Duration(milliseconds: 33),
      candidates: const [
        PutterCandidate(
          centerX: 115, centerY: 200,
          width: 80, height: 20,
          blobCount: 2, confidence: 0.95,
        ),
      ],
    );

    expect(recovered?.centerX, 115);
    expect(recovered?.frameIndex, 3);
  });

  test("selects nearest putter candidate", () {
    final tracker = PutterTracker();

    tracker.track(
      frameIndex: 1,
      timestamp: Duration.zero,
      candidates: const [
        PutterCandidate(
          centerX: 100, centerY: 200,
          width: 80, height: 20,
          blobCount: 2, confidence: 0.95,
        ),
      ],
    );

    final result = tracker.track(
      frameIndex: 2,
      timestamp: const Duration(milliseconds: 17),
      candidates: const [
        PutterCandidate(
          centerX: 110, centerY: 200,
          width: 80, height: 20,
          blobCount: 2, confidence: 0.80,
        ),
        PutterCandidate(
          centerX: 190, centerY: 200,
          width: 80, height: 20,
          blobCount: 2, confidence: 0.99,
        ),
      ],
    );

    expect(result?.centerX, 110);
  });
}
