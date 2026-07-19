import 'dart:math' as math;

/// パターヘッドの運動から、ボール初速を計算する物理モデル。
class ImpactPhysics {
  const ImpactPhysics._();

  /// ヘッドスピードからボール初速を計算する。
  ///
  /// [headSpeed]       インパクト時のヘッドスピード（m/s）
  /// [impactEfficiency] インパクト効率
  ///                    1.0ならヘッドスピードと同じボール初速
  ///                    1.0未満ならエネルギー損失あり
  static double calculateBallSpeed({
    required double headSpeed,
    double transferCoefficient = 1.65,
    double impactEfficiency = 1.0,
  }) {
    final safeHeadSpeed = math.max(0.0, headSpeed);
    final safeTransferCoefficient = math.max(0.0, transferCoefficient);
    final safeImpactEfficiency = math.max(0.0, impactEfficiency);

    return safeHeadSpeed * safeTransferCoefficient * safeImpactEfficiency;
  }
}
