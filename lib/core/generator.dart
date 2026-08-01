/// Генератор головоломок судоку.
///
/// Алгоритм в два шага:
/// 1. Генерируем полностью решённую доску: запускаем решатель на пустой
///    доске со случайным порядком кандидатов — backtracking сам «соберёт»
///    случайную валидную сетку.
/// 2. «Выкапываем» клетки: удаляем цифры по одной в случайном порядке.
///    После каждого удаления проверяем, что решение осталось ЕДИНСТВЕННЫМ
///    (countSolutions с ранним выходом). Если решений стало два —
///    возвращаем цифру на место и пробуем другую клетку.
///
/// Сложность (пока) регулируется количеством оставленных подсказок.
/// Позже её можно заменить на анализ техник решения — для этого
/// достаточно поменять реализацию generate(), интерфейс не изменится.
library;

import 'dart:math';

import 'board.dart';
import 'solver.dart';

/// Уровни сложности. Диапазон подсказок задаём прямо в enum —
/// в Dart enum'ы могут иметь поля и конструкторы, это удобно.
enum Difficulty {
  easy(minClues: 36, maxClues: 40),
  medium(minClues: 30, maxClues: 34),
  hard(minClues: 25, maxClues: 29),
  expert(minClues: 22, maxClues: 24);

  const Difficulty({required this.minClues, required this.maxClues});

  final int minClues;
  final int maxClues;
}

/// Результат генерации: головоломка + её решение (для подсказок
/// и проверки ошибок нам всегда нужен «ответ»).
class GeneratedPuzzle {
  final SudokuBoard puzzle;
  final SudokuBoard solution;
  final Difficulty difficulty;

  const GeneratedPuzzle({
    required this.puzzle,
    required this.solution,
    required this.difficulty,
  });

  int get clueCount => puzzle.filledCount;
}

class SudokuGenerator {
  final Random _random;

  /// [seed] позволяет получать воспроизводимые доски — удобно для тестов
  /// и пригодится для «ежедневных головоломок» (seed = номер дня).
  SudokuGenerator({int? seed}) : _random = seed != null ? Random(seed) : Random();

  /// Шаг 1: полностью решённая случайная доска.
  SudokuBoard generateSolvedBoard() {
    final cells = List<int>.filled(cellCount, 0);
    // Решатель со случайным порядком кандидатов на пустой доске
    // всегда находит решение (пустая доска решаема тривиально).
    final ok = SudokuSolver.solve(cells, random: _random);
    assert(ok, 'Решатель не смог заполнить пустую доску — это баг');
    return SudokuBoard.fromList(cells);
  }

  /// Шаг 2: головоломка нужной сложности.
  ///
  /// Нюанс: жадное выкапывание не всегда добирается до цели — иногда
  /// «застревает» на 25–26 подсказках, когда любая следующая клетка
  /// ломает уникальность. Поэтому на сложных уровнях делаем до
  /// [maxAttempts] попыток с разных стартовых досок и берём лучшую.
  GeneratedPuzzle generate(Difficulty difficulty, {int maxAttempts = 5}) {
    // Целимся в случайное число подсказок внутри диапазона уровня,
    // чтобы доски одного уровня немного отличались.
    final targetClues = difficulty.minClues +
        _random.nextInt(difficulty.maxClues - difficulty.minClues + 1);

    GeneratedPuzzle? best;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final result = _digHoles(targetClues, difficulty);
      if (best == null || result.clueCount < best.clueCount) {
        best = result;
      }
      // Попали в диапазон уровня — этого достаточно, выходим.
      if (best.clueCount <= difficulty.maxClues) break;
    }
    return best!;
  }

  /// Одна попытка: новая решённая доска + выкапывание до [targetClues].
  GeneratedPuzzle _digHoles(int targetClues, Difficulty difficulty) {
    final solution = generateSolvedBoard();
    final cells = solution.toMutableList();

    // Случайный порядок обхода клеток — от него зависит,
    // какая именно головоломка получится из этой доски.
    final order = List<int>.generate(cellCount, (i) => i)..shuffle(_random);

    int clues = cellCount; // сейчас заполнена вся доска
    for (final index in order) {
      if (clues <= targetClues) break; // цель достигнута

      final saved = cells[index];
      cells[index] = 0; // пробуем удалить...

      // countSolutions меняет список в процессе работы, но всегда
      // возвращает его в исходное состояние (ставит и откатывает).
      if (SudokuSolver.countSolutions(cells) == 1) {
        clues--; // удаление безопасно: решение всё ещё единственное
      } else {
        cells[index] = saved; // появилось второе решение — откат
      }
    }

    return GeneratedPuzzle(
      puzzle: SudokuBoard.fromList(cells),
      solution: solution,
      difficulty: difficulty,
    );
  }
}