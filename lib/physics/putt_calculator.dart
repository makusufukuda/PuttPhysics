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
    required double stimp,
    required String grassType,
    required String weather,
  }) {
    // 減速度
    double stimpFactor = 10.0 / stimp;

    double grassFactor = 1.0;

    if (grassType == "高麗") {
      grassFactor = 1.20;
    } else if (grassType == "ティフトン") {
      grassFactor = 1.10;
    } else if (grassType == "バミューダ") {
      grassFactor = 1.15;
    }
    double weatherFactor = 1.0;

    if (weather == "雨") {
      weatherFactor = 1.25;
    } else if (weather == "曇り") {
      weatherFactor = 1.05;
    }

    double deceleration = mu * stimpFactor * grassFactor * weatherFactor * g;

    // 停止時間
    double stopTime = speed / deceleration;

    // 転がり距離
    double distance = speed * speed / (2 * deceleration);

    return PuttResult(distance: distance, stopTime: stopTime);
  }
}
