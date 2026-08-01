/// Точка входа. Светлая и тёмная темы переключаются автоматически
/// вслед за системной настройкой (themeMode: ThemeMode.system).
library;

import 'package:flutter/material.dart';

import 'ui/game_screen.dart';

void main() => runApp(const SudokuApp());

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.indigo;
    return MaterialApp(
      title: 'Судоку',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const GameScreen(),
    );
  }
}
