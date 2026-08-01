/// Тесты «человеческого» решателя.
library;

import 'package:test/test.dart';
import 'package:sudoku/core/board.dart';
import 'package:sudoku/core/generator.dart';
import 'package:sudoku/core/solver.dart';
import 'package:sudoku/core/techniques.dart';

void main() {
  group('TechniqueFinder', () {
    test('naked single: решённая доска минус одна клетка', () {
      final solved = SudokuGenerator(seed: 5).generateSolvedBoard();
      final expected = solved.cell(4, 4);
      final board = solved.withCell(4, 4, 0);

      final hint = TechniqueFinder.find(board);

      expect(hint, isNotNull);
      expect(hint!.technique, 'naked_single');
      expect((hint.row, hint.col), (4, 4));
      expect(hint.value, expected);
      expect(hint.explanation, contains('$expected'));
      expect(hint.involved, isNotEmpty);
    });

    test('hidden single: сконструированная позиция', () {
      // Четыре пятёрки расставлены так, что в строке 1 пятёрка может
      // стоять только в клетке (1,1) — хотя у самой клетки кандидатов
      // много (naked single тут не сработает).
      final board = SudokuBoard.empty()
          .withCell(1, 4, 5) // закрывает клетки (0,3..5) через квадрат
          .withCell(2, 7, 5) // закрывает (0,6..8) через квадрат
          .withCell(4, 1, 5) // закрывает (0,1) через столбец
          .withCell(7, 2, 5); // закрывает (0,2) через столбец

      final hint = TechniqueFinder.find(board);

      expect(hint, isNotNull);
      expect(hint!.technique, 'hidden_single');
      expect((hint.row, hint.col), (0, 0));
      expect(hint.value, 5);
      // «Виновники» — все пятёрки на доске.
      expect(hint.involved.toSet(),
          {(1, 4), (2, 7), (4, 1), (7, 2)});
    });

    test('на пустой доске логических ходов нет', () {
      expect(TechniqueFinder.find(SudokuBoard.empty()), isNull);
    });

    test('свойство: каждый найденный ход совпадает с решением', () {
      // Прогоняем несколько сгенерированных головоломок: применяем
      // подсказки одну за другой и сверяем каждую с настоящим решением.
      for (final seed in [1, 2, 3]) {
        final gen = SudokuGenerator(seed: seed);
        final puzzle = gen.generate(Difficulty.medium);
        final solution = puzzle.solution;

        var board = puzzle.puzzle;
        int applied = 0;
        while (true) {
          final hint = TechniqueFinder.find(board);
          if (hint == null) break;
          expect(solution.cell(hint.row, hint.col), hint.value,
              reason: 'техника ${hint.technique} дала цифру, '
                  'не совпадающую с решением (seed $seed)');
          board = board.withCell(hint.row, hint.col, hint.value);
          applied++;
          expect(applied, lessThan(cellCount), reason: 'зацикливание');
        }
        expect(applied, greaterThan(0),
            reason: 'на средней доске должен найтись хотя бы один ход');
        // Если техники дошли до конца — доска обязана быть решена верно.
        if (board.isFull) {
          expect(board.isSolved, isTrue);
        }
      }
    });

    test('после хода по подсказке позиция остаётся решаемой', () {
      final gen = SudokuGenerator(seed: 9);
      final puzzle = gen.generate(Difficulty.easy);
      final hint = TechniqueFinder.find(puzzle.puzzle)!;
      final next = puzzle.puzzle.withCell(hint.row, hint.col, hint.value);
      expect(SudokuSolver.hasUniqueSolution(next), isTrue);
    });
  });
}
