/// «Человеческий» решатель: находит ходы приёмами живого игрока
/// и умеет объяснять их.
///
/// Устройство. Техники делятся на два сорта:
///  - РАССТАНОВОЧНЫЕ дают готовый ход: naked single (в клетке один
///    кандидат) и hidden single (цифре некуда больше встать в доме);
///  - ВЫЧЁРКИВАЮЩИЕ хода не дают, но сужают кандидатов: naked pair,
///    pointing pair, X-wing.
///
/// Поиск подсказки — цикл: пробуем расстановочные; если тишина —
/// применяем одно вычёркивание и пробуем снова. Найденный ход
/// возвращается вместе с цепочкой вычёркиваний, которые к нему привели.
///
/// «Дом» — обобщение строки, столбца и квадрата: 9 клеток, где каждая
/// цифра обязана встретиться ровно один раз.
///
/// Бонус на будущее: у каждой техники есть ранг сложности (hardness) —
/// прогнав головоломку через solveByTechniques, можно честно оценить
/// её уровень по самой продвинутой понадобившейся технике.
library;

import 'board.dart';
import 'solver.dart';

/// Ранги сложности техник (для будущей оценки уровня головоломок).
const Map<String, int> techniqueHardness = {
  'naked_single': 1,
  'hidden_single': 2,
  'naked_pair': 3,
  'pointing_pair': 4,
  'x_wing': 5,
};

/// Найденный ход с полным рассуждением.
class TechniqueHint {
  final int row;
  final int col;
  final int value;

  /// Самая продвинутая техника в цепочке — её и показываем игроку.
  final String technique;

  /// Готовый русский текст: подготовительные вычёркивания + сам вывод.
  final String explanation;

  /// Клетки-«виновники» для подсветки на поле.
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

/// Один шаг вычёркивания (внутренняя кухня цепочки).
class _Elimination {
  final String technique;
  final String description;
  final List<(int, int)> cells;
  const _Elimination(this.technique, this.description, this.cells);
}

/// Дом: человекочитаемое имя + индексы девяти клеток.
typedef _House = (String name, List<int> indexes);

class TechniqueFinder {
  TechniqueFinder._();

  /// Первый логический ход или null, если техники бессильны.
  static TechniqueHint? find(SudokuBoard board) {
    if (board.hasConflicts) return null;

    final cells = board.toMutableList();
    // Сетка кандидатов: для каждой пустой клетки — множество возможных
    // цифр. Вычёркивающие техники будут ужимать именно её.
    final grid = <Set<int>>[
      for (int i = 0; i < cellCount; i++)
        cells[i] == 0 ? SudokuSolver.candidatesFor(cells, i).toSet() : <int>{}
    ];

    final steps = <_Elimination>[];
    // 81 итерации заведомо хватает: каждая либо даёт ход, либо ужимает
    // кандидатов, а ужимать бесконечно нельзя.
    for (int iteration = 0; iteration < cellCount; iteration++) {
      final placement = _nakedSingle(board, grid) ?? _hiddenSingle(board, grid);
      if (placement != null) return _withChain(placement, steps);

      final elimination =
          _nakedPair(grid) ?? _pointingPair(grid) ?? _xWing(grid);
      if (elimination == null) return null; // арсенал исчерпан
      steps.add(elimination);
    }
    return null;
  }

  /// Прогоняет доску техниками до упора. Возвращает (сколько клеток
  /// удалось поставить, максимальный ранг использованных техник).
  /// Это заготовка честной оценки сложности головоломок.
  static (int placed, int maxHardness) solveByTechniques(SudokuBoard board) {
    var current = board;
    int placed = 0;
    int maxHardness = 0;
    while (true) {
      final hint = find(current);
      if (hint == null) break;
      current = current.withCell(hint.row, hint.col, hint.value);
      placed++;
      final h = techniqueHardness[hint.technique] ?? 0;
      if (h > maxHardness) maxHardness = h;
    }
    return (placed, maxHardness);
  }

  // ---------- Сборка итоговой подсказки ----------

  static TechniqueHint _withChain(
      TechniqueHint placement, List<_Elimination> steps) {
    if (steps.isEmpty) return placement;

    // Объяснение: последние 1-2 вычёркивания словами, остальные — счётом,
    // иначе текст разрастается. Виновники: клетки последнего шага + свои.
    final tail = steps.length > 2 ? steps.sublist(steps.length - 2) : steps;
    final skipped = steps.length - tail.length;
    final prefix = StringBuffer('Подготовка: ');
    if (skipped > 0) prefix.write('после $skipped вычёркиваний — ');
    prefix.write(tail.map((e) => e.description).join('; '));
    prefix.write('. Затем: ');

    final involved = <(int, int)>{...placement.involved, ...steps.last.cells};
    final hardest = [placement.technique, for (final s in steps) s.technique]
        .reduce((a, b) =>
            (techniqueHardness[a] ?? 0) >= (techniqueHardness[b] ?? 0) ? a : b);

    return TechniqueHint(
      row: placement.row,
      col: placement.col,
      value: placement.value,
      technique: hardest,
      explanation: '$prefix${placement.explanation}',
      involved: involved.toList(),
    );
  }

  // ---------- Расстановочные техники ----------

  static TechniqueHint? _nakedSingle(SudokuBoard board, List<Set<int>> grid) {
    for (int i = 0; i < cellCount; i++) {
      if (grid[i].length != 1) continue;
      final row = i ~/ boardSize, col = i % boardSize;
      final value = grid[i].single;
      return TechniqueHint(
        row: row,
        col: col,
        value: value,
        technique: 'naked_single',
        explanation:
            'в клетке ${_cellName(row, col)} остался единственный кандидат '
            '— цифра $value.',
        involved: _filledPeers(board, row, col),
      );
    }
    return null;
  }

  static TechniqueHint? _hiddenSingle(SudokuBoard board, List<Set<int>> grid) {
    for (final (houseName, indexes) in _houses()) {
      for (int digit = 1; digit <= 9; digit++) {
        final spots = [
          for (final i in indexes)
            if (grid[i].contains(digit)) i
        ];
        if (spots.length != 1) continue;
        final index = spots.single;
        // Пропускаем случай, который поймал бы naked single — он проще.
        if (grid[index].length == 1) continue;
        final row = index ~/ boardSize, col = index % boardSize;
        return TechniqueHint(
          row: row,
          col: col,
          value: digit,
          technique: 'hidden_single',
          explanation: 'в $houseName цифра $digit помещается только в клетку '
              '${_cellName(row, col)} — остальные клетки для неё закрыты.',
          involved: _digitPositions(board, digit),
        );
      }
    }
    return null;
  }

  // ---------- Вычёркивающие техники ----------

  /// Naked pair: две клетки дома с одинаковой парой кандидатов {a, b}.
  /// Раз a и b обязаны занять эти две клетки, из остальных клеток дома
  /// они вычёркиваются.
  static _Elimination? _nakedPair(List<Set<int>> grid) {
    for (final (houseName, indexes) in _houses()) {
      final pairCells = [
        for (final i in indexes)
          if (grid[i].length == 2) i
      ];
      for (int a = 0; a < pairCells.length; a++) {
        for (int b = a + 1; b < pairCells.length; b++) {
          final i1 = pairCells[a], i2 = pairCells[b];
          if (!_sameSet(grid[i1], grid[i2])) continue;

          bool removed = false;
          for (final i in indexes) {
            if (i == i1 || i == i2) continue;
            for (final d in grid[i1]) {
              removed = grid[i].remove(d) || removed;
            }
          }
          if (!removed) continue; // пара есть, но вычёркивать нечего

          final digits = grid[i1].toList()..sort();
          return _Elimination(
            'naked_pair',
            'клетки ${_cellNameAt(i1)} и ${_cellNameAt(i2)} в $houseName '
                'делят пару ${digits[0]}/${digits[1]}, поэтому эти цифры '
                'вычеркнуты из остальных клеток',
            [_pos(i1), _pos(i2)],
          );
        }
      }
    }
    return null;
  }

  /// Pointing pair: в квадрате все кандидаты цифры стоят в одной строке
  /// (или столбце) — значит, в этой строке за пределами квадрата цифры
  /// быть не может.
  static _Elimination? _pointingPair(List<Set<int>> grid) {
    for (int b = 0; b < boardSize; b++) {
      final boxRow = (b ~/ boxSize) * boxSize;
      final boxCol = (b % boxSize) * boxSize;
      final indexes = [
        for (int r = 0; r < boxSize; r++)
          for (int c = 0; c < boxSize; c++)
            (boxRow + r) * boardSize + (boxCol + c)
      ];
      for (int digit = 1; digit <= 9; digit++) {
        final spots = [
          for (final i in indexes)
            if (grid[i].contains(digit)) i
        ];
        if (spots.length < 2) continue;

        final rows = {for (final i in spots) i ~/ boardSize};
        final cols = {for (final i in spots) i % boardSize};

        if (rows.length == 1) {
          final row = rows.single;
          bool removed = false;
          for (int c = 0; c < boardSize; c++) {
            final i = row * boardSize + c;
            if (c >= boxCol && c < boxCol + boxSize)
              continue; // внутри квадрата
            removed = grid[i].remove(digit) || removed;
          }
          if (removed) {
            return _Elimination(
              'pointing_pair',
              'в квадрате ${b + 1} все кандидаты цифры $digit стоят '
                  'в строке ${row + 1}, поэтому вне квадрата из этой строки '
                  '$digit вычеркнута',
              [for (final i in spots) _pos(i)],
            );
          }
        }
        if (cols.length == 1) {
          final col = cols.single;
          bool removed = false;
          for (int r = 0; r < boardSize; r++) {
            final i = r * boardSize + col;
            if (r >= boxRow && r < boxRow + boxSize) continue;
            removed = grid[i].remove(digit) || removed;
          }
          if (removed) {
            return _Elimination(
              'pointing_pair',
              'в квадрате ${b + 1} все кандидаты цифры $digit стоят '
                  'в столбце ${col + 1}, поэтому вне квадрата из этого '
                  'столбца $digit вычеркнута',
              [for (final i in spots) _pos(i)],
            );
          }
        }
      }
    }
    return null;
  }

  /// X-wing: цифра встречается кандидатом ровно в двух клетках строки —
  /// и в другой строке ровно в тех же двух столбцах. Четыре клетки
  /// образуют прямоугольник; цифра обязана встать в два его
  /// противоположных угла, поэтому из остальных клеток этих СТОЛБЦОВ
  /// она вычёркивается. (И симметрично для столбцов/строк.)
  static _Elimination? _xWing(List<Set<int>> grid) {
    for (int digit = 1; digit <= 9; digit++) {
      // По строкам.
      final rowSpots = <int, List<int>>{}; // строка -> колонки кандидатов
      for (int r = 0; r < boardSize; r++) {
        final cols = [
          for (int c = 0; c < boardSize; c++)
            if (grid[r * boardSize + c].contains(digit)) c
        ];
        if (cols.length == 2) rowSpots[r] = cols;
      }
      final rows = rowSpots.keys.toList();
      for (int a = 0; a < rows.length; a++) {
        for (int b = a + 1; b < rows.length; b++) {
          final r1 = rows[a], r2 = rows[b];
          if (!_sameList(rowSpots[r1]!, rowSpots[r2]!)) continue;
          final (c1, c2) = (rowSpots[r1]![0], rowSpots[r1]![1]);

          bool removed = false;
          for (int r = 0; r < boardSize; r++) {
            if (r == r1 || r == r2) continue;
            removed = grid[r * boardSize + c1].remove(digit) || removed;
            removed = grid[r * boardSize + c2].remove(digit) || removed;
          }
          if (removed) {
            return _Elimination(
              'x_wing',
              'цифра $digit в строках ${r1 + 1} и ${r2 + 1} возможна только '
                  'в столбцах ${c1 + 1} и ${c2 + 1} (прямоугольник X-wing), '
                  'поэтому из остальных клеток этих столбцов $digit '
                  'вычеркнута',
              [(r1, c1), (r1, c2), (r2, c1), (r2, c2)],
            );
          }
        }
      }
      // По столбцам (симметрично).
      final colSpots = <int, List<int>>{};
      for (int c = 0; c < boardSize; c++) {
        final rowsOf = [
          for (int r = 0; r < boardSize; r++)
            if (grid[r * boardSize + c].contains(digit)) r
        ];
        if (rowsOf.length == 2) colSpots[c] = rowsOf;
      }
      final cols = colSpots.keys.toList();
      for (int a = 0; a < cols.length; a++) {
        for (int b = a + 1; b < cols.length; b++) {
          final c1 = cols[a], c2 = cols[b];
          if (!_sameList(colSpots[c1]!, colSpots[c2]!)) continue;
          final (r1, r2) = (colSpots[c1]![0], colSpots[c1]![1]);

          bool removed = false;
          for (int c = 0; c < boardSize; c++) {
            if (c == c1 || c == c2) continue;
            removed = grid[r1 * boardSize + c].remove(digit) || removed;
            removed = grid[r2 * boardSize + c].remove(digit) || removed;
          }
          if (removed) {
            return _Elimination(
              'x_wing',
              'цифра $digit в столбцах ${c1 + 1} и ${c2 + 1} возможна только '
                  'в строках ${r1 + 1} и ${r2 + 1} (прямоугольник X-wing), '
                  'поэтому из остальных клеток этих строк $digit вычеркнута',
              [(r1, c1), (r1, c2), (r2, c1), (r2, c2)],
            );
          }
        }
      }
    }
    return null;
  }

  // ---------- Вспомогательное ----------

  static Iterable<_House> _houses() sync* {
    for (int r = 0; r < boardSize; r++) {
      yield (
        'строке ${r + 1}',
        [for (int c = 0; c < boardSize; c++) r * boardSize + c]
      );
    }
    for (int c = 0; c < boardSize; c++) {
      yield (
        'столбце ${c + 1}',
        [for (int r = 0; r < boardSize; r++) r * boardSize + c]
      );
    }
    for (int b = 0; b < boardSize; b++) {
      yield (
        'квадрате ${b + 1}',
        [
          for (int r = 0; r < boxSize; r++)
            for (int c = 0; c < boxSize; c++)
              ((b ~/ boxSize) * boxSize + r) * boardSize +
                  (b % boxSize) * boxSize +
                  c
        ]
      );
    }
  }

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

  static List<(int, int)> _digitPositions(SudokuBoard board, int digit) => [
        for (int r = 0; r < boardSize; r++)
          for (int c = 0; c < boardSize; c++)
            if (board.cell(r, c) == digit) (r, c)
      ];

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _sameList(List<int> a, List<int> b) =>
      a.length == b.length &&
      [for (int i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  static (int, int) _pos(int index) => (index ~/ boardSize, index % boardSize);

  static String _cellName(int row, int col) => '(${row + 1}, ${col + 1})';

  static String _cellNameAt(int index) =>
      _cellName(index ~/ boardSize, index % boardSize);
}
