import 'tracked_ball.dart';

class TrackingSession {
  final List<TrackedBall> _balls = [];

  List<TrackedBall> get balls => List.unmodifiable(_balls);

  int get length => _balls.length;

  bool get isEmpty => _balls.isEmpty;

  bool get isNotEmpty => _balls.isNotEmpty;

  TrackedBall? get first => _balls.isEmpty ? null : _balls.first;

  TrackedBall? get latest => _balls.isEmpty ? null : _balls.last;

  void add(TrackedBall ball) {
    _balls.add(ball);
  }

  void clear() {
    _balls.clear();
  }
}
