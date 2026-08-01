/// Состояние текущей партии и операции над ним.
///
/// Ключевое решение: UI не трогает игровую логику напрямую. Виджеты
/// «спрашивают» контроллер (что в клетке? она конфликтная?) и «просят»
/// его (выбери клетку, поставь цифру). Контроллер меняет состояние
/// и зовёт notifyListeners() — все подписанные виджеты перерисовываются.
///
/// Используем ChangeNotifier из самого Flutter — без внешних пакетов.
/// Это простейший вариант «наблюдаемого состояния»: та же идея, что
/// в Provider/Riverpod, но без магии — видно, как всё работает.
/// Позже, если захотим, переезд на Riverpod будет механическим.
library;

import 'package:flutter/foundation.dart';

import '../../core/board.dart';
import '../../core/generator.dart';

class GameController extends ChangeNotifier {
  final SudokuGenerator _generator = SudokuGenerator();

  late GeneratedPuzzle _puzzle; // головоломка + её решение
  late SudokuBoard _board; // текущее состояние с ходами игрока

  int? selectedRow;
  int? selectedCol;

  GameController() {
    newGame(Difficulty.easy);
  }

  // ---------- Чтение состояния (для виджетов) ----------

  SudokuBoard get board => _board;
  Difficulty get difficulty => _puzzle.difficulty;
  bool get isSolved => _board.isSolved;

  /// Клетка — исходная подсказка? Их менять нельзя, и рисуются они иначе.
  bool isGiven(int row, int col) => _puzzle.puzzle.cell(row, col) != 0;

  /// Цифра в клетке нарушает правила? (для подсветки конфликтов)
  bool isConflict(int row, int col) {
    final v = _board.cell(row, col);
    return v != 0 && !_board.isValidPlacement(row, col, v);
  }

  /// Значение в выбранной клетке (0, если ничего не выбрано или пусто).
  int get selectedValue {
    if (selectedRow == null || selectedCol == null) return 0;
    return _board.cell(selectedRow!, selectedCol!);
  }

  /// «Соседи» выбранной клетки: та же строка, столбец или квадрат 3×3.
  bool isPeerOfSelection(int row, int col) {
    final sr = selectedRow, sc = selectedCol;
    if (sr == null || sc == null) return false;
    if (row == sr && col == sc) return false; // сама выбранная — не сосед
    final sameBox =
        row ~/ boxSize == sr ~/ boxSize && col ~/ boxSize == sc ~/ boxSize;
    return row == sr || col == sc || sameBox;
  }

  // ---------- Действия игрока ----------

  void select(int row, int col) {
    selectedRow = row;
    selectedCol = col;
    notifyListeners();
  }

  /// Поставить цифру в выбранную клетку. Подсказки трогать нельзя.
  /// Повторное нажатие той же цифры стирает её — удобный жест.
  void input(int digit) {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null) return;
    if (isGiven(r, c)) return;
    if (isSolved) return; // партия окончена

    final next = _board.cell(r, c) == digit ? 0 : digit;
    _board = _board.withCell(r, c, next); // НОВАЯ доска — старая цела
    notifyListeners();
  }

  void erase() {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null || isGiven(r, c)) return;
    _board = _board.withCell(r, c, 0);
    notifyListeners();
  }

  /// Новая партия. Генерация занимает миллисекунды, поэтому пока
  /// зовём её прямо из UI-потока; вынос в Isolate — на этапе полировки.
  void newGame(Difficulty difficulty) {
    _puzzle = _generator.generate(difficulty);
    _board = _puzzle.puzzle;
    selectedRow = null;
    selectedCol = null;
    notifyListeners();
  }
}
