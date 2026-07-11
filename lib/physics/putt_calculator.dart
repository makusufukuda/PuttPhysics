import 'dart:math';

class PuttResult {
  final double distance;
  final double stopTime;
  final double breakAmount;
  final bool cupIn;

  PuttResult({
    required this.distance,
    required this.stopTime,
    required this.breakAmount,
    required this.cupIn,
  });
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
    required double slope,
    required String grain,
    required String slopeDirection,
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
    double grainFactor = 1.0;

    if (grain == "順目") {
      grainFactor = 1.10;
    } else if (grain == "逆目") {
      grainFactor = 0.90;
    }
    double slopeFactor = 1.0 + (slope * 0.15);
    double deceleration =
        mu * stimpFactor * grassFactor * weatherFactor * slopeFactor * g;

    // 停止時間
    double stopTime = speed / deceleration;
    double spinFactor = 1.0 + (forwardSpin / 1000.0);
    double angleFactor = 1.0 + (launchAngle * 0.03);

    // 転がり距離
    double distance =
        (speed * speed / (2 * deceleration)) *
        spinFactor *
        angleFactor *
        grainFactor;
    // 横ズレ量
    double spinBreak = sideSpin * stopTime * 0.0002;

    double slopeBreak = slope * distance * 0.002;

    double directionFactor = slopeDirection == "右下り" ? 1.0 : -1.0;

    double breakAmount = (spinBreak + slopeBreak) * directionFactor;
    bool cupIn = (breakAmount.abs() * 100) <= 5.4;

    return PuttResult(
      distance: distance,
      stopTime: stopTime,
      breakAmount: breakAmount,
      cupIn: cupIn,
    );
  }
}
