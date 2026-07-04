import 'package:flutter/material.dart';
import '../physics/putt_calculator.dart';
import 'result_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String club = "パター";

  final speedController = TextEditingController();
  final angleController = TextEditingController();
  final spinController = TextEditingController();
  final sideSpinController = TextEditingController();

  @override
  void dispose() {
    speedController.dispose();
    angleController.dispose();
    spinController.dispose();
    sideSpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("解析開始")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text("クラブ種類", style: TextStyle(fontSize: 18)),

            DropdownButton<String>(
              value: club,
              isExpanded: true,
              items: const [DropdownMenuItem(value: "パター", child: Text("パター"))],
              onChanged: (value) {
                setState(() {
                  club = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: speedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "ボール初速 (m/s)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: angleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "打ち出し角 (°)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: spinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "順回転 (rpm)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: sideSpinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "横回転 (rpm)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  final speed = double.tryParse(speedController.text) ?? 0.0;

                  final angle = double.tryParse(angleController.text) ?? 0.0;

                  final forwardSpin =
                      double.tryParse(spinController.text) ?? 0.0;

                  final sideSpin =
                      double.tryParse(sideSpinController.text) ?? 0.0;

                  final result = PuttCalculator.calculate(
                    speed: speed,
                    launchAngle: angle,
                    forwardSpin: forwardSpin,
                    sideSpin: sideSpin,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        speed: speed,
                        angle: angle,
                        forwardSpin: forwardSpin,
                        sideSpin: sideSpin,
                        distance: result.distance,
                        stopTime: result.stopTime,
                      ),
                    ),
                  );
                },
                child: const Text("計算する", style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
