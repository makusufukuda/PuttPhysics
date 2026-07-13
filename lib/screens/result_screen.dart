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
              distance < 3.0
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
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();

    path.moveTo(20, size.height / 2);

    path.cubicTo(
      size.width * 0.35,
      size.height / 2,

      size.width * 0.90,
      size.height / 2 - (breakAmount * 300),

      size.width - 20,
      size.height / 2 - (breakAmount * 300),
    );

    canvas.drawPath(path, paint);

    final ballPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(20, size.height / 2), 6, ballPaint);

    canvas.drawCircle(
      Offset(size.width - 20, size.height / 2),
      8,
      Paint()..color = Colors.red,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
