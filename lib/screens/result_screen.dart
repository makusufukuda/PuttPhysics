import 'dart:math' as math;
import 'package:flutter/material.dart';

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
              child: CustomPaint(painter: PuttPathPainter(breakAmount)),
            ),
          ],
        ),
      ),
    );
  }
}

class PuttPathPainter extends CustomPainter {
  final double breakAmount;

  PuttPathPainter(this.breakAmount);

  @override
  void paint(Canvas canvas, Size size) {
    const startMargin = 20.0;
    const steps = 120;

    final startX = startMargin;
    final endX = size.width - startMargin;
    final centerY = size.height / 2;

    final availableWidth = endX - startX;

    // 進行方向を少しずつ変化させて軌道を作る
    final rawPoints = <Offset>[Offset.zero];

    double x = 0.0;
    double y = 0.0;
    double heading = 0.0;

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;

      // 前半はほぼ直進し、後半ほど傾斜の影響を強くする
      final slowdownEffect = math.pow(t, 3.2).toDouble();

      // breakAmountの符号で左右を決める
      final direction = breakAmount >= 0 ? -1.0 : 1.0;

      // 進行方向を少しずつ変える
      heading += direction * slowdownEffect * 0.0018;

      x += math.cos(heading);
      y += math.sin(heading);

      rawPoints.add(Offset(x, y));
    }

    final rawEndX = rawPoints.last.dx;
    final rawEndY = rawPoints.last.dy;

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

    final path = Path();

    for (int i = 0; i < rawPoints.length; i++) {
      final point = rawPoints[i];

      final normalizedX = rawEndX == 0 ? 0.0 : point.dx / rawEndX;

      final normalizedY = rawEndY == 0 ? 0.0 : point.dy / rawEndY;

      final screenX = startX + normalizedX * availableWidth;

      // breakAmountが正なら上、負なら下へ表示
      final signedBreak = breakAmount >= 0 ? -visualBreak : visualBreak;

      final screenY = centerY + normalizedY * signedBreak;

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
