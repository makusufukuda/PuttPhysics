import 'dart:math' as math;

/// 時計方向＋傾斜％
///
/// directionHour
/// 12 = 真っ直ぐ上り
/// 3  = 右
/// 6  = 真っ直ぐ下り
/// 9  = 左
class SlopeConverter {
  static ({double longitudinalSlope, double lateralSlope}) convert({
    required double directionHour,
    required double slopePercent,
  }) {
    // 12時方向を0°
    final angleDeg = (directionHour % 12) * 30.0;

    final angleRad = angleDeg * math.pi / 180.0;

    final longitudinal = slopePercent * math.cos(angleRad);

    final lateral = slopePercent * math.sin(angleRad);

    return (longitudinalSlope: longitudinal, lateralSlope: lateral);
  }
}
