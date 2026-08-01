/// Решатель судоку на основе backtracking (поиска с возвратом).
///
/// Работает с изменяемым List<int> (а не с SudokuBoard) сознательно:
/// решатель делает тысячи «поставил — откатил», и создавать новый
/// объект доски на каждый шаг было бы очень медленно. Изменяемость
/// здесь спрятана ВНУТРИ решателя, наружу отдаётся готовый результат.
library;

import 'dart:math';

import 'board.dart';

class SudokuSolver {
  SudokuSolver._(); // только статические методы, экземпляры не нужны

  /// Список цифр, которые можно поставить в клетку [index]
  /// (не конфликтуют со строкой, столбцом и квадратом).
  static List<int> candidatesFor(List<int> cells, int index) {
    final row = index ~/ boardSize;
    final col = index % boardSize;
    // used[v] == true, если цифра v уже занята
    final used = List<bool>.filled(10, false);
    for (int i = 0; i < boardSize; i++) {
      used[cells[row * boardSize + i]] = true; // строка
      used[cells[i * boardSize + col]] = true; // столбец
    }
    final boxRow = (row ~/ boxSize) * boxSize;
    final boxCol = (col ~/ boxSize) * boxSize;
    for (int r = boxRow; r < boxRow + boxSize; r++) {
      for (int c = boxCol; c < boxCol + boxSize; c++) {
        used[cells[r * boardSize + c]] = true;
      }
    }
    return [
      for (int v = 1; v <= 9; v++)
        if (!used[v]) v
    ];
  }

  /// КЛЮЧЕВАЯ ОПТИМИЗАЦИЯ (эвристика MRV — minimum remaining values):
  /// вместо «первой попавшейся» пустой клетки выбираем ту, у которой
  /// МЕНЬШЕ всего кандидатов. Если где-то остался один кандидат — идём
  /// туда сразу; если где-то кандидатов ноль — ветка тупиковая, и мы
  /// узнаём об этом немедленно, а не после долгого перебора.
  /// Без этой эвристики подсчёт решений на «экспертных» досках
  /// может занимать десятки секунд, с ней — доли секунды.
  ///
  /// Возвращает (индекс клетки, её кандидаты) или (-1, []) если пустых нет.
  static (int, List<int>) _bestEmptyCell(List<int> cells) {
    int bestIndex = -1;
    List<int> bestCandidates = const [];
    for (int i = 0; i < cellCount; i++) {
      if (cells[i] != 0) continue;
      final cands = candidatesFor(cells, i);
      if (bestIndex == -1 || cands.length < bestCandidates.length) {
        bestIndex = i;
        bestCandidates = cands;
        if (cands.length <= 1) break; // лучше уже не найти
      }
    }
    return (bestIndex, bestCandidates);
  }

  /// Конфликтуют ли уже расставленные цифры между собой.
  ///
  /// ВАЖНЫЙ УРОК (найден благодаря зависшему тесту): backtracking проверяет
  /// только клетки, которые ставит сам, а исходные подсказки принимает
  /// на веру. Если подсказки противоречивы (две пятёрки в одной строке),
  /// решения нет — но чтобы ДОКАЗАТЬ это перебором, нужны миллионы шагов:
  /// доказать отсутствие решения куда дороже, чем найти существующее.
  /// Мгновенная проверка на входе закрывает проблему: 30+ секунд → 0.01 мс.
  static bool _givensConflict(List<int> cells) {
    for (int i = 0; i < cellCount; i++) {
      final v = cells[i];
      if (v == 0) continue;
      cells[i] = 0; // временно убираем, чтобы клетка не мешала сама себе
      final ok = candidatesFor(cells, i).contains(v);
      cells[i] = v;
      if (!ok) return true;
    }
    return false;
  }

  /// Решает доску «на месте» (меняет переданный список).
  /// Возвращает true, если решение найдено.
  ///
  /// [random] нужен генератору: перемешивая кандидатов, мы получаем
  /// каждый раз РАЗНУЮ решённую доску. Решателю порядок не важен.
  static bool solve(List<int> cells, {Random? random}) {
    // Проверяем подсказки ОДИН раз на входе, а не в каждом шаге рекурсии —
    // поэтому сам перебор вынесен в отдельный приватный метод.
    if (_givensConflict(cells)) return false;
    return _solveRecursive(cells, random);
  }

  static bool _solveRecursive(List<int> cells, Random? random) {
    final (index, candidates) = _bestEmptyCell(cells);
    if (index == -1) return true; // пустых клеток нет — решено

    final order = List<int>.from(candidates);
    if (random != null) order.shuffle(random);

    for (final value in order) {
      cells[index] = value; // пробуем цифру...
      if (_solveRecursive(cells, random)) return true;
      cells[index] = 0; // ...не вышло — откатываемся (backtracking)
    }
    return false; // ни одна цифра не подошла — тупик
  }

  /// Считает количество решений, но не больше [limit].
  ///
  /// Ключевое решение: для проверки уникальности не нужно знать точное
  /// число решений — достаточно понять, «одно или больше одного».
  /// Поэтому limit = 2: как только найдено второе решение, перебор
  /// немедленно прекращается. Это радикально ускоряет генерацию.
  static int countSolutions(List<int> cells, {int limit = 2}) {
    // Та же защита: у противоречивой доски решений ноль, и это надо
    // отвечать мгновенно (иначе полная доска с конфликтом дала бы «1»).
    if (_givensConflict(cells)) return 0;
    return _countRecursive(cells, limit);
  }

  static int _countRecursive(List<int> cells, int limit) {
    final (index, candidates) = _bestEmptyCell(cells);
    if (index == -1) return 1; // доска заполнена — это одно решение

    int total = 0;
    for (final value in candidates) {
      cells[index] = value;
      total += _countRecursive(cells, limit - total);
      cells[index] = 0;
      if (total >= limit) break; // ранний выход
    }
    return total;
  }

  /// Удобная обёртка: единственно ли решение у головоломки.
  static bool hasUniqueSolution(SudokuBoard board) =>
      countSolutions(board.toMutableList()) == 1;

  /// Решённая копия доски или null, если решения нет.
  static SudokuBoard? solved(SudokuBoard board) {
    final cells = board.toMutableList();
    return solve(cells) ? SudokuBoard.fromList(cells) : null;
  }
}
