import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/ball_search_roi.dart';

void main() {
  test('Stationary ball uses smaller ROI', () {
    expect(
      BallSearchRoi.margin(
        movementStarted: false,
        movementPending: false,
        missedFrames: 0,
      ),
      250.0,
    );
  });

  test('Pending movement keeps safety margin', () {
    expect(
      BallSearchRoi.margin(
        movementStarted: false,
        movementPending: true,
        missedFrames: 0,
      ),
      400.0,
    );
  });

  test('Moving ball keeps existing margin', () {
    expect(
      BallSearchRoi.margin(
        movementStarted: true,
        movementPending: false,
        missedFrames: 0,
      ),
      400.0,
    );
  });

  test('Missed frames expand ROI', () {
    expect(
      BallSearchRoi.margin(
        movementStarted: true,
        movementPending: false,
        missedFrames: 2,
      ),
      700.0,
    );
  });
}
