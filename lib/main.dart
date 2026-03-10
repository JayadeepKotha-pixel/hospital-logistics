import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HealthcareApp());
}

class HealthcareApp extends StatelessWidget {
  const HealthcareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Healthcare Logistics',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.indigo).copyWith(
          secondary: Colors.tealAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FF),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Healthcare Logistics System"),
      ),
      body: const Center(
        child: Text(
          "Welcome to Healthcare Logistics App",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}