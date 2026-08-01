/// Unit-тесты игровой логики. Запуск: `flutter test` (или `dart test`).
///
/// Обратите внимание: генераторы в тестах создаются с фиксированным seed,
/// чтобы тесты были воспроизводимыми (одинаковыми при каждом запуске).
library;

import 'package:test/test.dart';
import 'package:sudoku/core/board.dart';
import 'package:sudoku/core/generator.dart';
import 'package:sudoku/core/solver.dart';

/// Известная головоломка с единственным решением (для проверки решателя).
/// 0 = пустая клетка.
const _knownPuzzle = [
  5, 3, 0, 0, 7, 0, 0, 0, 0, //
  6, 0, 0, 1, 9, 5, 0, 0, 0, //
  0, 9, 8, 0, 0, 0, 0, 6, 0, //
  8, 0, 0, 0, 6, 0, 0, 0, 3, //
  4, 0, 0, 8, 0, 3, 0, 0, 1, //
  7, 0, 0, 0, 2, 0, 0, 0, 6, //
  0, 6, 0, 0, 0, 0, 2, 8, 0, //
  0, 0, 0, 4, 1, 9, 0, 0, 5, //
  0, 0, 0, 0, 8, 0, 0, 7, 9, //
];

void main() {
  group('SudokuBoard', () {
    test('пустая доска: 0 заполненных, без конфликтов', () {
      final board = SudokuBoard.empty();
      expect(board.filledCount, 0);
      expect(board.hasConflicts, isFalse);
      expect(board.isSolved, isFalse);
    });

    test('withCell возвращает новую доску, не меняя старую', () {
      final a = SudokuBoard.empty();
      final b = a.withCell(0, 0, 5);
      expect(a.cell(0, 0), 0, reason: 'исходная доска не должна измениться');
      expect(b.cell(0, 0), 5);
    });

    test('isValidPlacement находит конфликт в строке, столбце и квадрате', () {
      final board = SudokuBoard.empty().withCell(0, 0, 5);
      expect(board.isValidPlacement(0, 8, 5), isFalse); // та же строка
      expect(board.isValidPlacement(8, 0, 5), isFalse); // тот же столбец
      expect(board.isValidPlacement(1, 1, 5), isFalse); // тот же квадрат
      expect(board.isValidPlacement(4, 4, 5), isTrue); // далеко — можно
      expect(board.isValidPlacement(0, 8, 3), isTrue); // другая цифра
    });

    test('fromList отклоняет неправильные данные', () {
      expect(() => SudokuBoard.fromList([1, 2, 3]), throwsArgumentError);
      expect(
        () => SudokuBoard.fromList(List<int>.filled(cellCount, 10)),
        throwsArgumentError,
      );
    });
  });

  group('SudokuSolver', () {
    test('решает известную головоломку', () {
      final board = SudokuBoard.fromList(_knownPuzzle);
      final solved = SudokuSolver.solved(board);
      expect(solved, isNotNull);
      expect(solved!.isSolved, isTrue);
      // Решение не должно менять исходные подсказки
      expect(solved.cell(0, 0), 5);
      expect(solved.cell(0, 4), 7);
    });

    test('у известной головоломки ровно одно решение', () {
      expect(
        SudokuSolver.countSolutions(List<int>.from(_knownPuzzle)),
        1,
      );
    });

    test('у пустой доски много решений (счётчик останавливается на 2)', () {
      final cells = List<int>.filled(cellCount, 0);
      expect(SudokuSolver.countSolutions(cells), 2);
    });

    test('противоречивая доска не решается (и отвечает мгновенно)', () {
      // Две пятёрки в одной строке — решения нет. Без проверки подсказок
      // на входе этот тест «зависал» на десятки секунд: доказать
      // отсутствие решения перебором очень дорого. Теперь — мгновенно.
      final cells = List<int>.filled(cellCount, 0);
      cells[0] = 5;
      cells[1] = 5;
      final stopwatch = Stopwatch()..start();
      expect(SudokuSolver.solve(cells), isFalse);
      expect(SudokuSolver.countSolutions(cells), 0);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'проверка конфликтов на входе должна отвечать мгновенно');
    });

    test('countSolutions возвращает список в исходное состояние', () {
      final cells = List<int>.from(_knownPuzzle);
      SudokuSolver.countSolutions(cells);
      expect(cells, _knownPuzzle);
    });
  });

  group('SudokuGenerator', () {
    test('generateSolvedBoard даёт валидную полную доску', () {
      final gen = SudokuGenerator(seed: 1);
      final board = gen.generateSolvedBoard();
      expect(board.isFull, isTrue);
      expect(board.hasConflicts, isFalse);
      expect(board.isSolved, isTrue);
    });

    test('одинаковый seed — одинаковая доска, разный — разная', () {
      final a = SudokuGenerator(seed: 42).generateSolvedBoard();
      final b = SudokuGenerator(seed: 42).generateSolvedBoard();
      final c = SudokuGenerator(seed: 43).generateSolvedBoard();
      expect(a.toMutableList(), b.toMutableList());
      expect(a.toMutableList(), isNot(equals(c.toMutableList())));
    });

    for (final difficulty in Difficulty.values) {
      test('генерирует корректную головоломку уровня $difficulty', () {
        final gen = SudokuGenerator(seed: 7);
        final result = gen.generate(difficulty);

        // 1. Решение единственно — главное свойство хорошего судоку.
        expect(SudokuSolver.hasUniqueSolution(result.puzzle), isTrue);

        // 2. Головоломка действительно ведёт к приложенному решению.
        final solved = SudokuSolver.solved(result.puzzle);
        expect(solved!.toMutableList(), result.solution.toMutableList());

        // 3. Подсказки совпадают с решением (мы удаляли, а не меняли).
        for (int i = 0; i < cellCount; i++) {
          final v = result.puzzle.cellAt(i);
          if (v != 0) expect(v, result.solution.cellAt(i));
        }

        // 4. Число подсказок в диапазоне уровня. Небольшой запас сверху:
        // жадное выкапывание изредка не добирается до цели даже
        // за несколько попыток — это нормально для такого алгоритма.
        expect(result.clueCount, greaterThanOrEqualTo(difficulty.minClues));
        expect(result.clueCount, lessThanOrEqualTo(difficulty.maxClues + 3));
      });
    }
  });
}
