import '../models/marker_calibration_result.dart';
import '../models/real_world_point.dart';

class PerspectiveCalibration {
  const PerspectiveCalibration._();

  static RealWorldPoint? imageToMillimeters({
    required MarkerCalibrationResult calibration,
    required double x,
    required double y,
  }) {
    final source = [
      [calibration.topLeftX, calibration.topLeftY],
      [calibration.topRightX, calibration.topRightY],
      [calibration.bottomLeftX, calibration.bottomLeftY],
      [calibration.bottomRightX, calibration.bottomRightY],
    ];

    const target = [
      [0.0, 0.0],
      [700.0, 0.0],
      [0.0, 237.0],
      [700.0, 237.0],
    ];

    final matrix = _solveHomography(source, target);

    if (matrix == null) {
      return null;
    }

    final denominator = (matrix[6] * x) + (matrix[7] * y) + 1.0;

    if (denominator.abs() < 0.0000001) {
      return null;
    }

    final realX = ((matrix[0] * x) + (matrix[1] * y) + matrix[2]) / denominator;
    final realY = ((matrix[3] * x) + (matrix[4] * y) + matrix[5]) / denominator;

    return RealWorldPoint(xMillimeters: realX, yMillimeters: realY);
  }

  static List<double>? _solveHomography(
    List<List<double>> source,
    List<List<double>> target,
  ) {
    final matrix = List.generate(8, (_) => List<double>.filled(9, 0.0));

    for (var i = 0; i < 4; i++) {
      final x = source[i][0];
      final y = source[i][1];
      final u = target[i][0];
      final v = target[i][1];

      final row1 = i * 2;
      final row2 = row1 + 1;

      matrix[row1][0] = x;
      matrix[row1][1] = y;
      matrix[row1][2] = 1.0;
      matrix[row1][6] = -u * x;
      matrix[row1][7] = -u * y;
      matrix[row1][8] = u;

      matrix[row2][3] = x;
      matrix[row2][4] = y;
      matrix[row2][5] = 1.0;
      matrix[row2][6] = -v * x;
      matrix[row2][7] = -v * y;
      matrix[row2][8] = v;
    }

    for (var column = 0; column < 8; column++) {
      var pivotRow = column;

      for (var row = column + 1; row < 8; row++) {
        if (matrix[row][column].abs() > matrix[pivotRow][column].abs()) {
          pivotRow = row;
        }
      }

      if (matrix[pivotRow][column].abs() < 0.0000001) {
        return null;
      }

      if (pivotRow != column) {
        final temp = matrix[column];
        matrix[column] = matrix[pivotRow];
        matrix[pivotRow] = temp;
      }

      final pivot = matrix[column][column];

      for (var col = column; col < 9; col++) {
        matrix[column][col] /= pivot;
      }

      for (var row = 0; row < 8; row++) {
        if (row == column) {
          continue;
        }

        final factor = matrix[row][column];

        for (var col = column; col < 9; col++) {
          matrix[row][col] -= factor * matrix[column][col];
        }
      }
    }

    return List.generate(8, (index) => matrix[index][8]);
  }
}
