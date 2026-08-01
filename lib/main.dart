/// Точка входа. Этап 4: main стал асинхронным — прежде чем рисовать UI,
/// нужно открыть локальное хранилище hive. Это типичный паттерн Flutter:
/// ensureInitialized -> подготовка сервисов -> runApp.
library;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/save_repository.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  // Обязательная строка перед любой асинхронщиной до runApp:
  // связывает Flutter с платформой (иначе плагины вроде hive упадут).
  WidgetsFlutterBinding.ensureInitialized();

  // Hive сам выбирает место хранения: папка приложения на iOS/Android,
  // IndexedDB в браузере. Офлайн работает везде.
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('sudoku');

  runApp(SudokuApp(repository: SaveRepository(box)));
}

class SudokuApp extends StatelessWidget {
  final SaveRepository repository;

  const SudokuApp({super.key, required this.repository});

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
      home: GameScreen(repository: repository),
    );
  }
}
