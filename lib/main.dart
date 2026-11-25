import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const TodoManagerApp());
}

class TodoManagerApp extends StatelessWidget {
  const TodoManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TODO Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
