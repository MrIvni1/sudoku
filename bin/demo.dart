/// Консольная проверка этапа 1. Запуск из корня проекта:
///   dart run bin/demo.dart
///
/// Генерирует по головоломке на каждый уровень сложности,
/// печатает её, решение и время генерации.
library;

import 'package:sudoku/core/generator.dart';
import 'package:sudoku/core/solver.dart';

void main() {
  final generator = SudokuGenerator();

  for (final difficulty in Difficulty.values) {
    final stopwatch = Stopwatch()..start();
    final result = generator.generate(difficulty);
    stopwatch.stop();

    print('=== ${difficulty.name.toUpperCase()} '
        '(подсказок: ${result.clueCount}, '
        'сгенерировано за ${stopwatch.elapsedMilliseconds} мс) ===\n');
    print('Головоломка:');
    print(result.puzzle);
    print('Решение:');
    print(result.solution);
    print('Решение единственно: '
        '${SudokuSolver.hasUniqueSolution(result.puzzle)}\n');
  }
}