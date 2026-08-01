import 'package:flutter/material.dart';

void main() => runApp(const SudokuApp());

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Судоку',
      home: Scaffold(
        body: Center(child: Text('Судоку — этап 2 скоро')),
      ),
    );
  }
}
