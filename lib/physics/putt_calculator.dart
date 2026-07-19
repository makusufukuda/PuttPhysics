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
  final List<PuttPoint> trajectory;

  const PuttResult({
    required this.distance,
    required this.stopTime,
    required this.breakAmount,
    required this.cupIn,
    required this.cupSpeed,
    this.trajectory = const [],
  });
}

class PuttCalculator {
  // 重力加速度
  static const double g = 9.81;

  // グリーン摩擦係数
  // 現段階では固定値として使用する
  static const double mu = 0.08;

  // シミュレーション時間間隔
  static const double timeStep = 0.01;

  // 異常値による無限ループ防止
  static const int maxSimulationSteps = 10000;

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
    required String longitudinalSlopeDirection,
  }) {
    final safeSpeed = math.max(0.0, speed);
    final safeStimp = math.max(0.1, stimp);
    final safeTargetDistance = math.max(0.0, targetDistance);

    // スティンプ値から転がり抵抗係数を計算

    // 芝種類による補正
    double grassFactor = 1.0;

    if (grassType == '高麗') {
      grassFactor = 1.20;
    } else if (grassType == 'ティフトン') {
      grassFactor = 1.10;
    } else if (grassType == 'バミューダ') {
      grassFactor = 1.15;
    }

    // 天候による補正
    double weatherFactor = 1.0;

    if (weather == '雨') {
      weatherFactor = 1.25;
    } else if (weather == '曇り') {
      weatherFactor = 1.05;
    }

    // 芝目による補正
    double grainFactor = 1.0;

    if (grain == '順目') {
      grainFactor = 1.10;
    } else if (grain == '逆目') {
      grainFactor = 0.90;
    }
    double longitudinalAcceleration = 0.0;
    double lateralAcceleration = 0.0;

    if (slopeDirection == "右下り") {
      final theta = math.atan(slope / 100.0);
      lateralAcceleration = g * math.sin(theta);
    } else if (slopeDirection == "左下り") {
      final theta = math.atan(slope / 100.0);
      lateralAcceleration = -g * math.sin(theta);
    }
    if (longitudinalSlopeDirection == "上り") {
      final theta = math.atan(slope / 100.0);
      longitudinalAcceleration = g * math.sin(theta);
    } else if (longitudinalSlopeDirection == "下り") {
      final theta = math.atan(slope / 100.0);
      longitudinalAcceleration = -g * math.sin(theta);
    }
    // 前後方向の一定減速度
    // スティンプ値(ft) → m
    final stimpDistance = safeStimp * 0.3048;

    // USGA Stimp Meter の初速 (m/s)
    const launchSpeed = 1.83;

    // スティンプ値から転がり抵抗係数を計算
    final mu = (launchSpeed * launchSpeed) / (2.0 * g * stimpDistance);
    final frictionDeceleration = mu * grassFactor * weatherFactor * g;

    final deceleration = math.max(
      0.01,
      frictionDeceleration + longitudinalAcceleration,
    );

    // 順回転補正
    final spinFactor = math.max(0.1, 1.0 + (forwardSpin / 1000.0));

    // 打ち出し角補正
    final angleFactor = math.max(0.1, 1.0 + (launchAngle * 0.03));

    // 従来の計算結果との連続性を保つため、
    // 各補正を実効初速に変換する
    final effectiveSpeed =
        safeSpeed * math.sqrt(spinFactor * angleFactor * grainFactor);

    // 前後方向シミュレーション初期値
    double time = 0.0;

    double x = 0.0;
    double y = 0.0;

    double vx = effectiveSpeed;
    double vy = 0.0;

    double cupSpeed = 0.0;
    bool reachedCup = safeTargetDistance <= 0.0;

    // 停止時間の推定値
    // 横回転による横加速度を決めるために使用する
    final estimatedStopTime = deceleration > 0.0
        ? effectiveSpeed / deceleration
        : 0.0;

    // 横回転による仮の横ズレ
    final spinBreak = sideSpin * estimatedStopTime * 0.0002;

    // 横回転による横加速度
    final spinAcceleration = estimatedStopTime > 0.0
        ? 2.0 *
              spinBreak /
              math.max(estimatedStopTime * estimatedStopTime, 0.0001)
        : 0.0;

    // 左右傾斜の重力加速度と横回転を合成
    final ay = lateralAcceleration + spinAcceleration;

    final trajectory = <PuttPoint>[const PuttPoint(x: 0.0, y: 0.0)];

    int step = 0;

    while (vx > 0.0 && deceleration > 0.0 && step < maxSimulationSteps) {
      // 最後のステップでは速度が0になるまでの時間だけ進める
      final stepDuration = math.min(timeStep, vx / deceleration);

      // 次の前後速度
      final nextVx = math.max(0.0, vx - deceleration * stepDuration);

      // 次の横速度
      final nextVy = vy + ay * stepDuration;

      // 区間平均速度を使って位置を更新
      final nextX = x + ((vx + nextVx) / 2.0) * stepDuration;

      final nextY = y + ((vy + nextVy) / 2.0) * stepDuration;

      // 今回の時間区間内でカップ位置を通過したか判定
      if (!reachedCup &&
          x < safeTargetDistance &&
          nextX >= safeTargetDistance) {
        final distanceToCup = safeTargetDistance - x;

        final remainingSpeedSquared =
            vx * vx - 2.0 * deceleration * distanceToCup;

        cupSpeed = remainingSpeedSquared > 0.0
            ? math.sqrt(remainingSpeedSquared)
            : 0.0;

        reachedCup = true;
      }

      time += stepDuration;
      x = nextX;
      y = nextY;
      vx = nextVx;
      vy = nextVy;

      trajectory.add(PuttPoint(x: x, y: y));

      step++;
    }

    // シミュレーション結果
    final distance = x;
    final stopTime = time;
    final breakAmount = y;

    // カップ幅判定
    // カップ直径10.8cmの半分を許容幅とする
    final withinCupWidth = (breakAmount.abs() * 100.0) <= 5.4;

    // カップ到達速度の上限
    final acceptableCupSpeed = cupSpeed <= 0.8;

    final cupIn = reachedCup && withinCupWidth && acceptableCupSpeed;

    return PuttResult(
      distance: distance,
      stopTime: stopTime,
      breakAmount: breakAmount,
      cupIn: cupIn,
      cupSpeed: cupSpeed,
      trajectory: trajectory,
    );
  }
}
