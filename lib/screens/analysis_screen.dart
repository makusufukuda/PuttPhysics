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
  String grassType = "ベント";
  String weather = "晴れ";

  final stimpController = TextEditingController(text: "10.0");
  final speedController = TextEditingController();
  final angleController = TextEditingController();
  final spinController = TextEditingController();
  final sideSpinController = TextEditingController();

  @override
  void dispose() {
    stimpController.dispose();
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
              controller: stimpController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "グリーンスピード（Stimp）",
                hintText: "例：10.2",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            const Text("芝種", style: TextStyle(fontSize: 18)),

            DropdownButton<String>(
              value: grassType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: "ベント", child: Text("ベント")),
                DropdownMenuItem(value: "高麗", child: Text("高麗")),
                DropdownMenuItem(value: "ティフトン", child: Text("ティフトン")),
                DropdownMenuItem(value: "バミューダ", child: Text("バミューダ")),
              ],
              onChanged: (value) {
                setState(() {
                  grassType = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            const Text("天候", style: TextStyle(fontSize: 18)),

            DropdownButton<String>(
              value: weather,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: "晴れ", child: Text("晴れ")),
                DropdownMenuItem(value: "曇り", child: Text("曇り")),
                DropdownMenuItem(value: "雨", child: Text("雨")),
              ],
              onChanged: (value) {
                setState(() {
                  weather = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: speedController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "ボール初速 (m/s)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: angleController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "打ち出し角 (°)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: spinController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "順回転 (rpm)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: sideSpinController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                  final stimp = double.tryParse(stimpController.text) ?? 10.0;
                  final selectedGrass = grassType;
                  final selectedWeather = weather;
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
                    stimp: stimp,
                    grassType: grassType,
                    weather: weather,
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
