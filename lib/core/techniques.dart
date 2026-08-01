/// «Человеческий» решатель: находит ходы теми же приёмами, которыми
/// пользуется живой игрок, и умеет ОБЪЯСНЯТЬ их.
///
/// Отличие от SudokuSolver принципиальное: backtracking решает перебором
/// и не может объяснить ход («я попробовал, и получилось» — не объяснение).
/// Техника же — это логический вывод из текущей позиции: его можно
/// рассказать словами и показать клетки, из-за которых он верен.
///
/// Техники проверяются от простой к сложной; возвращается первая
/// найденная. Сейчас реализованы две базовые:
///  - naked single: в клетке остался единственный кандидат;
///  - hidden single: цифра помещается только в одну клетку строки,
///    столбца или квадрата (даже если у клетки есть и другие кандидаты).
/// Модуль расширяем: naked pairs, pointing pairs, X-wing добавятся сюда
/// же — и заодно дадут честную оценку сложности головоломок.
library;

import 'board.dart';
import 'solver.dart';

/// Найденный ход с полным рассуждением.
class TechniqueHint {
  final int row;
  final int col;
  final int value;

  /// Машинное имя техники ('naked_single', 'hidden_single').
  final String technique;

  /// Объяснение для игрока, готовый русский текст.
  final String explanation;

  /// Клетки-«виновники» — те, из-за которых вывод верен.
  /// UI подсвечивает их, чтобы логику было видно глазами.
  final List<(int, int)> involved;

  const TechniqueHint({
    required this.row,
    required this.col,
    required this.value,
    required this.technique,
    required this.explanation,
    required this.involved,
  });
}

class TechniqueFinder {
  TechniqueFinder._();

  /// Первый найденный логический ход или null, если базовые техники
  /// в этой позиции бессильны.
  static TechniqueHint? find(SudokuBoard board) =>
      _nakedSingle(board) ?? _hiddenSingle(board);

  // ---------- Naked single ----------

  static TechniqueHint? _nakedSingle(SudokuBoard board) {
    final cells = board.toMutableList();
    for (int i = 0; i < cellCount; i++) {
      if (cells[i] != 0) continue;
      final candidates = SudokuSolver.candidatesFor(cells, i);
      if (candidates.length != 1) continue;

      final row = i ~/ boardSize;
      final col = i % boardSize;
      return TechniqueHint(
        row: row,
        col: col,
        value: candidates.single,
        technique: 'naked_single',
        explanation:
            'В клетке ${_cellName(row, col)} может стоять только цифра '
            '${candidates.single}: все остальные восемь цифр уже заняты '
            'в её строке, столбце или квадрате 3×3.',
        involved: _filledPeers(board, row, col),
      );
    }
    return null;
  }

  /// Заполненные «соседи» клетки — они и вычёркивают кандидатов.
  static List<(int, int)> _filledPeers(SudokuBoard board, int row, int col) {
    final result = <(int, int)>{};
    for (int i = 0; i < boardSize; i++) {
      if (i != col && board.cell(row, i) != 0) result.add((row, i));
      if (i != row && board.cell(i, col) != 0) result.add((i, col));
    }
    final boxRow = (row ~/ boxSize) * boxSize;
    final boxCol = (col ~/ boxSize) * boxSize;
    for (int r = boxRow; r < boxRow + boxSize; r++) {
      for (int c = boxCol; c < boxCol + boxSize; c++) {
        if ((r != row || c != col) && board.cell(r, c) != 0) result.add((r, c));
      }
    }
    return result.toList();
  }

  // ---------- Hidden single ----------

  static TechniqueHint? _hiddenSingle(SudokuBoard board) {
    final cells = board.toMutableList();

    // «Дом» — обобщение строки, столбца и квадрата: набор из 9 клеток,
    // где каждая цифра обязана встретиться ровно один раз.
    final houses = <(String, List<int>)>[
      for (int r = 0; r < boardSize; r++)
        ('строке ${r + 1}', [for (int c = 0; c < boardSize; c++) r * boardSize + c]),
      for (int c = 0; c < boardSize; c++)
        ('столбце ${c + 1}', [for (int r = 0; r < boardSize; r++) r * boardSize + c]),
      for (int b = 0; b < boardSize; b++)
        (
          'квадрате ${b + 1}',
          [
            for (int r = 0; r < boxSize; r++)
              for (int c = 0; c < boxSize; c++)
                ((b ~/ boxSize) * boxSize + r) * boardSize +
                    (b % boxSize) * boxSize + c
          ]
        ),
    ];

    for (final (houseName, indexes) in houses) {
      for (int digit = 1; digit <= 9; digit++) {
        if (indexes.any((i) => cells[i] == digit)) continue; // уже стоит

        // В каких пустых клетках дома эта цифра вообще возможна?
        final spots = [
          for (final i in indexes)
            if (cells[i] == 0 && SudokuSolver.candidatesFor(cells, i).contains(digit)) i
        ];
        if (spots.length != 1) continue;

        final index = spots.single;
        final row = index ~/ boardSize;
        final col = index % boardSize;
        return TechniqueHint(
          row: row,
          col: col,
          value: digit,
          technique: 'hidden_single',
          explanation:
              'В $houseName цифра $digit помещается только в клетку '
              '${_cellName(row, col)}: остальные свободные клетки этого '
              '${_houseKind(houseName)} «закрыты» — их видят такие же '
              'цифры $digit из соседних строк, столбцов и квадратов.',
          involved: _digitPositions(board, digit),
        );
      }
    }
    return null;
  }

  /// Все цифры [digit] на доске: показываем игроку, ЧТО именно
  /// закрывает остальные клетки дома.
  static List<(int, int)> _digitPositions(SudokuBoard board, int digit) => [
        for (int r = 0; r < boardSize; r++)
          for (int c = 0; c < boardSize; c++)
            if (board.cell(r, c) == digit) (r, c)
      ];

  static String _cellName(int row, int col) =>
      '(строка ${row + 1}, столбец ${col + 1})';

  static String _houseKind(String houseName) => houseName.startsWith('строке')
      ? 'ряда'
      : houseName.startsWith('столбце')
          ? 'столбца'
          : 'квадрата';
}
