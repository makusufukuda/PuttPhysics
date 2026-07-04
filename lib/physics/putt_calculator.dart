import 'dart:math';

class PuttResult {
  final double distance;
  final double stopTime;

  PuttResult({required this.distance, required this.stopTime});
}

class PuttCalculator {
  // 重力加速度
  static const double g = 9.81;

  // グリーン摩擦係数（まずは固定）
  static const double mu = 0.08;

  static PuttResult calculate({
    required double speed,
    required double launchAngle,
    required double forwardSpin,
    required double sideSpin,
  }) {
    // 減速度
    double deceleration = mu * g;

    // 停止時間
    double stopTime = speed / deceleration;

    // 転がり距離
    double distance = speed * speed / (2 * deceleration);

    return PuttResult(distance: distance, stopTime: stopTime);
  }
}
