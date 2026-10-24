import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/services/initial_ball_search_region.dart';

void main() {
  final markers = <String, Offset>{
    'topLeft': const Offset(100, 100),
    'topRight': const Offset(300, 100),
    'bottomLeft': const Offset(50, 500),
    'bottomRight': const Offset(350, 500),
  };

  test('手前半分のボールを検出する', () {
    expect(
      InitialBallSearchRegion.contains(
        markers: markers,
        point: const Offset(200, 400),
      ),
      isTrue,
    );
  });

  test('奥半分の候補を除外する', () {
    expect(
      InitialBallSearchRegion.contains(
        markers: markers,
        point: const Offset(200, 200),
      ),
      isFalse,
    );
  });

  test('マーカーの外側の候補を除外する', () {
    expect(
      InitialBallSearchRegion.contains(
        markers: markers,
        point: const Offset(20, 400),
      ),
      isFalse,
    );
  });

  test('マーカーが不足している場合は除外する', () {
    expect(
      InitialBallSearchRegion.contains(
        markers: const <String, Offset>{},
        point: const Offset(200, 400),
      ),
      isFalse,
    );
  });
}
