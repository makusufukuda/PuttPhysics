import 'dart:math' as math;

class PuttPoint {
  final double x;
  final double y;

  const PuttPoint({required this.x, required this.y});
}

class PuttResult {
  final double distance;
  final double stopTime;
  final double breakAmount;
  final bool cupIn;
  final double cupSpeed;

  // ←追加
  final List<PuttPoint> trajectory;

  PuttResult({
    required this.distance,
    required this.stopTime,
    required this.breakAmount,
    required this.cupIn,
    required this.cupSpeed,
    // ←追加
    this.trajectory = const [],
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
    required double targetDistance,
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

    // 横回転による横ズレ
    double spinBreak = sideSpin * stopTime * 0.0002;

    // 傾斜による横ズレ
    double slopeBreak = slope * distance * 0.002;

    // 傾斜方向
    double directionFactor = slopeDirection == "右下り" ? 1.0 : -1.0;

    // 合計横ズレ
    double breakAmount = (spinBreak + slopeBreak) * directionFactor;

    // 各種補正を含めた実効初速
    final effectiveSpeed = math.sqrt(2 * deceleration * distance);

    // カップ位置での残り速度
    final remainingSpeedSquared =
        effectiveSpeed * effectiveSpeed - 2 * deceleration * targetDistance;

    final cupSpeed = remainingSpeedSquared > 0
        ? math.sqrt(remainingSpeedSquared)
        : 0.0;

    // カップイン判定
    final reachedCup = distance >= targetDistance;
    final withinCupWidth = (breakAmount.abs() * 100) <= 5.4;
    final acceptableCupSpeed = cupSpeed <= 0.8;

    final cupIn = reachedCup && withinCupWidth && acceptableCupSpeed;

    return PuttResult(
      distance: distance,
      stopTime: stopTime,
      breakAmount: breakAmount,
      cupIn: cupIn,
      cupSpeed: cupSpeed,
    );
  }
}
