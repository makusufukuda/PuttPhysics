import 'package:flutter_test/flutter_test.dart';

import 'package:putt_physics_v1/models/calibration_scale.dart';
import 'package:putt_physics_v1/models/marker_calibration_result.dart';
import 'package:putt_physics_v1/services/perspective_calibration.dart';

void main() {
  test('maps marker corners to real-world millimeters', () {
    const calibration = MarkerCalibrationResult(
      topScale: CalibrationScale(
        referenceDistanceMillimeters: 700,
        referenceDistancePixels: 500,
      ),
      bottomScale: CalibrationScale(
        referenceDistanceMillimeters: 700,
        referenceDistancePixels: 600,
      ),
      topDistancePixels: 500,
      bottomDistancePixels: 600,
      leftDistancePixels: 130,
      rightDistancePixels: 130,
      topLeftX: 100,
      topLeftY: 800,
      topRightX: 600,
      topRightY: 820,
      bottomLeftX: 40,
      bottomLeftY: 920,
      bottomRightX: 640,
      bottomRightY: 940,
      topReferenceY: 810,
      bottomReferenceY: 930,
    );

    final tl = PerspectiveCalibration.imageToMillimeters(
      calibration: calibration,
      x: 100,
      y: 800,
    );

    final tr = PerspectiveCalibration.imageToMillimeters(
      calibration: calibration,
      x: 600,
      y: 820,
    );

    final bl = PerspectiveCalibration.imageToMillimeters(
      calibration: calibration,
      x: 40,
      y: 920,
    );

    final br = PerspectiveCalibration.imageToMillimeters(
      calibration: calibration,
      x: 640,
      y: 940,
    );

    expect(tl, isNotNull);
    expect(tr, isNotNull);
    expect(bl, isNotNull);
    expect(br, isNotNull);

    expect(tl!.xMillimeters, closeTo(0, 0.001));
    expect(tl.yMillimeters, closeTo(0, 0.001));

    expect(tr!.xMillimeters, closeTo(700, 0.001));
    expect(tr.yMillimeters, closeTo(0, 0.001));

    expect(bl!.xMillimeters, closeTo(0, 0.001));
    expect(bl.yMillimeters, closeTo(237, 0.001));

    expect(br!.xMillimeters, closeTo(700, 0.001));
    expect(br.yMillimeters, closeTo(237, 0.001));
  });
}
