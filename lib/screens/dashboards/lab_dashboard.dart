import 'package:flutter/material.dart';

class LabDashboard extends StatelessWidget {
  const LabDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laboratory Dashboard")),
      body: const Center(
        child: Text(
          "Lab Panel\nReceive Samples & Upload Reports",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
