import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/putter_head_markers.dart';

void main() {
  group('PutterHeadMarkers', () {
    test('calculates center point between two markers', () {
      const markers = PutterHeadMarkers(
        frameIndex: 1,
        timestamp: Duration(milliseconds: 0),
        markerAX: 100,
        markerAY: 200,
        markerBX: 200,
        markerBY: 300,
      );

      expect(markers.centerX, 150);
      expect(markers.centerY, 250);
    });

    test('calculates orientation from marker A to marker B', () {
      const markers = PutterHeadMarkers(
        frameIndex: 1,
        timestamp: Duration(milliseconds: 0),
        markerAX: 100,
        markerAY: 200,
        markerBX: 200,
        markerBY: 200,
      );

      expect(markers.orientationDegrees, closeTo(0.0, 0.001));
    });
  });
}
