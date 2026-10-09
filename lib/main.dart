import 'package:flutter/material.dart';
import 'package:scamundo/pages/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCAMUndo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F2C59)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
