import 'package:flutter/material.dart';
import '../physics/putt_calculator.dart';

class ResultScreen extends StatelessWidget {
  final double speed;
  final double angle;
  final double forwardSpin;
  final double sideSpin;

  final double distance;
  final double stopTime;
  final double breakAmount;
  final bool cupIn;
  final double cupSpeed;
  final double targetDistance;
  final List<PuttPoint> trajectory;

  const ResultScreen({
    super.key,
    required this.speed,
    required this.angle,
    required this.forwardSpin,
    required this.sideSpin,
    required this.distance,
    required this.stopTime,
    required this.breakAmount,
    required this.cupIn,
    required this.cupSpeed,
    required this.targetDistance,
    required this.trajectory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("解析結果")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "入力値",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Text("ボール初速：$speed m/s"),
            Text("打ち出し角：$angle °"),
            Text("順回転：$forwardSpin rpm"),
            Text("横回転：$sideSpin rpm"),

            const SizedBox(height: 40),

            const Divider(),

            const SizedBox(height: 20),

            const Text(
              "解析結果",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Text(
              "推定転がり距離：${distance.toStringAsFixed(2)} m",
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 10),

            Text(
              "停止時間：${stopTime.toStringAsFixed(2)} 秒",
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 10),

            Text(
              "推定横ズレ：${(breakAmount * 100).toStringAsFixed(1)} cm",
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 10),

            Text(
              cupIn ? "⛳ カップイン予想" : "❌ カップ外れ予想",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "カップ到達速度：${cupSpeed.toStringAsFixed(2)} m/s",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 10),

            Text(
              distance < targetDistance
                  ? "△ ショート"
                  : cupSpeed < 0.5
                  ? "◎ 理想的なタッチ"
                  : cupSpeed < 1.0
                  ? "○ やや強め"
                  : "❌ 強すぎ",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: 320,
              height: 140,
              child: CustomPaint(
                painter: PuttPathPainter(
                  breakAmount,
                  targetDistance,
                  trajectory,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PuttPathPainter extends CustomPainter {
  final double breakAmount;
  final double targetDistance;
  final List<PuttPoint> trajectory;

  PuttPathPainter(this.breakAmount, this.targetDistance, this.trajectory);

  @override
  void paint(Canvas canvas, Size size) {
    const startMargin = 20.0;
    final startX = startMargin;
    final endX = size.width - startMargin;
    final centerY = size.height / 2;

    final availableWidth = endX - startX;
    final xScale = targetDistance <= 0.0
        ? 1.0
        : availableWidth / targetDistance;

    final rawPoints = trajectory
        .map((point) => Offset(point.x, point.y))
        .toList();

    if (rawPoints.isEmpty) {
      return;
    }

    // 実際の横ズレを画面表示用に拡大
    double visualBreak = breakAmount.abs() * 2500;

    // 小さな横ズレでも曲線を確認できる最低表示量
    if (breakAmount.abs() > 0 && visualBreak < 12) {
      visualBreak = 12;
    }

    // 画面からはみ出さないよう制限
    final maxVisualBreak = size.height * 0.35;

    if (visualBreak > maxVisualBreak) {
      visualBreak = maxVisualBreak;
    }

    final yScale = xScale;

    final path = Path();

    for (int i = 0; i < rawPoints.length; i++) {
      final point = rawPoints[i];

      final screenX = startX + point.dx * xScale;

      // breakAmountが正なら上、負なら下へ表示

      final screenY = centerY - point.dy * yScale;

      if (i == 0) {
        path.moveTo(screenX, screenY);
      } else {
        path.lineTo(screenX, screenY);
      }
    }

    final pathPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, pathPaint);

    // スタート位置
    canvas.drawCircle(
      Offset(startX, centerY),
      6,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );

    // カップ位置
    canvas.drawCircle(
      Offset(endX, centerY),
      8,
      Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant PuttPathPainter oldDelegate) {
    return oldDelegate.breakAmount != breakAmount;
  }
}
