import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/models/putter_tracking_session.dart';
import 'package:putt_physics_v1/models/tracked_putter.dart';

TrackedPutter makePutter(int frame, int milliseconds, double x) {
  return TrackedPutter(
    frameIndex: frame,
    timestamp: Duration(milliseconds: milliseconds),
    centerX: x,
    centerY: 200,
    width: 80,
    height: 20,
    confidence: 0.95,
  );
}

void main() {
  test('calculates putter speed', () {
    final session = PutterTrackingSession();

    session.add(makePutter(1, 0, 100));
    session.add(makePutter(2, 500, 200));

    final metrics = session.latestMetrics();

    expect(metrics, isNotNull);
    expect(metrics!.distancePixels, 100);
    expect(metrics.deltaTimeSeconds, 0.5);
    expect(metrics.speedPixelsPerSecond, 200);
  });

  test('calculates all frame speeds and peak speed', () {
    final session = PutterTrackingSession();

    session.add(makePutter(1, 0, 100));
    session.add(makePutter(2, 100, 110));
    session.add(makePutter(3, 200, 140));
    session.add(makePutter(4, 300, 145));

    final speeds = session.allFrameSpeeds();
    final peak = session.peakSpeed();

    expect(speeds.length, 3);
    expect(speeds[0].speedPixelsPerSecond, closeTo(100, 0.001));
    expect(speeds[1].speedPixelsPerSecond, closeTo(300, 0.001));
    expect(speeds[2].speedPixelsPerSecond, closeTo(50, 0.001));

    expect(peak, isNotNull);
    expect(peak!.previousFrame, 2);
    expect(peak.currentFrame, 3);
    expect(peak.speedPixelsPerSecond, closeTo(300, 0.001));
  });

  test('rejects skipped frames', () {
    final session = PutterTrackingSession();

    session.add(makePutter(1, 0, 100));
    session.add(makePutter(3, 500, 200));

    expect(session.latestMetrics(), isNull);
  });

  test('rejects invalid timestamps', () {
    final session = PutterTrackingSession();

    session.add(makePutter(1, 500, 100));
    session.add(makePutter(2, 500, 200));

    expect(session.length, 1);
    expect(session.latestMetrics(), isNull);
  });
}
