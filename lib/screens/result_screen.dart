import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final double speed;
  final double angle;
  final double forwardSpin;
  final double sideSpin;

  final double distance;
  final double stopTime;

  const ResultScreen({
    super.key,
    required this.speed,
    required this.angle,
    required this.forwardSpin,
    required this.sideSpin,
    required this.distance,
    required this.stopTime,
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
          ],
        ),
      ),
    );
  }
}
