import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/ball_candidate.dart';

void main() {
  group('BallCandidate', () {
    test('motion blur flag defaults to false', () {
      const candidate = BallCandidate(
        centerX: 100,
        centerY: 200,
        radius: 20,
        confidence: 0.9,
      );

      expect(candidate.isMotionBlur, isFalse);
    });

    test('can represent motion blur candidate', () {
      const candidate = BallCandidate(
        centerX: 100,
        centerY: 200,
        radius: 20,
        confidence: 0.8,
        isMotionBlur: true,
      );

      expect(candidate.isMotionBlur, isTrue);
      expect(candidate.isCombinedRedYellow, isFalse);
    });

    test('toString includes motion blur state', () {
      const candidate = BallCandidate(
        centerX: 100,
        centerY: 200,
        radius: 20,
        confidence: 0.8,
        isMotionBlur: true,
      );

      expect(candidate.toString(), contains('isMotionBlur: true'));
    });
  });
}
