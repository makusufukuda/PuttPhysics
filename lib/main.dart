import 'package:flutter/material.dart';
import 'screens/analysis_screen.dart';

void main() {
  runApp(const PuttPhysicsApp());
}

class PuttPhysicsApp extends StatelessWidget {
  const PuttPhysicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Putt Physics',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Putt Physics"), centerTitle: true),
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.golf_course, size: 90, color: Colors.green),

              const SizedBox(height: 20),

              const Text(
                "Putt Physics",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              const Text("Version 1.0", style: TextStyle(fontSize: 20)),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("解析開始"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AnalysisScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text("履歴"),
                  onPressed: null,
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text("設定"),
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
