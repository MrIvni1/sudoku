/// Состояние текущей партии и операции над ним.
///
/// Этап 3 добавил: историю ходов (undo), заметки-кандидаты, подсказки
/// с лимитом, таймер с паузой, счётчик ошибок и настройку подсветки
/// конфликтов. Обратите внимание, что core/ не изменился ни на строчку —
/// вся новая механика уместилась в контроллере и виджетах.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/generator.dart';

/// Снимок состояния для undo: доска + заметки на момент ДО хода.
///
/// Здесь окупается неизменяемость SudokuBoard: старую доску можно
/// просто положить в список — никакой будущий ход её не испортит,
/// потому что каждый ход создаёт новый объект. Заметки же — обычные
/// изменяемые Set'ы, поэтому их приходится копировать вручную.
class _Snapshot {
  final SudokuBoard board;
  final List<Set<int>> notes;
  const _Snapshot(this.board, this.notes);
}

class GameController extends ChangeNotifier {
  static const int hintsPerGame = 3;

  final SudokuGenerator _generator = SudokuGenerator();

  late GeneratedPuzzle _puzzle;
  late SudokuBoard _board;

  /// Заметки-кандидаты: по Set цифр на каждую из 81 клетки.
  /// Живут в контроллере, а не в SudokuBoard: ядро знает только правила
  /// судоку, а заметки — деталь интерфейса, правилам они безразличны.
  late List<Set<int>> _notes;

  final List<_Snapshot> _history = [];

  int? selectedRow;
  int? selectedCol;
  bool notesMode = false;
  bool highlightConflicts = true;
  int hintsLeft = hintsPerGame;
  int errorCount = 0;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  bool _paused = false;

  GameController() {
    // Stopwatch умеет измерять время, но не умеет «сообщать» о его ходе.
    // Поэтому раз в секунду будим слушателей сами — только когда часы
    // идут, чтобы на паузе и после победы не перерисовываться впустую.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stopwatch.isRunning) notifyListeners();
    });
    newGame(Difficulty.easy);
  }

  @override
  void dispose() {
    _ticker?.cancel(); // иначе таймер переживёт экран — утечка
    super.dispose();
  }

  // ---------- Чтение состояния (для виджетов) ----------

  SudokuBoard get board => _board;
  Difficulty get difficulty => _puzzle.difficulty;
  bool get isSolved => _board.isSolved;
  bool get isPaused => _paused;
  bool get canUndo => _history.isNotEmpty;
  Duration get elapsed => _stopwatch.elapsed;

  Set<int> notesAt(int row, int col) => _notes[row * boardSize + col];

  bool isGiven(int row, int col) => _puzzle.puzzle.cell(row, col) != 0;

  bool isConflict(int row, int col) {
    final v = _board.cell(row, col);
    return v != 0 && !_board.isValidPlacement(row, col, v);
  }

  int get selectedValue {
    if (selectedRow == null || selectedCol == null) return 0;
    return _board.cell(selectedRow!, selectedCol!);
  }

  bool isPeerOfSelection(int row, int col) {
    final sr = selectedRow, sc = selectedCol;
    if (sr == null || sc == null) return false;
    if (row == sr && col == sc) return false;
    final sameBox =
        row ~/ boxSize == sr ~/ boxSize && col ~/ boxSize == sc ~/ boxSize;
    return row == sr || col == sc || sameBox;
  }

  // ---------- Действия игрока ----------

  void select(int row, int col) {
    if (_paused) return;
    selectedRow = row;
    selectedCol = col;
    notifyListeners();
  }

  void toggleNotesMode() {
    notesMode = !notesMode;
    notifyListeners();
  }

  void toggleHighlightConflicts() {
    highlightConflicts = !highlightConflicts;
    notifyListeners();
  }

  /// Цифра из панели. В обычном режиме ставит/стирает цифру,
  /// в режиме заметок — включает/выключает кандидата в пустой клетке.
  void input(int digit) {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null || isGiven(r, c) || isSolved || _paused) return;

    if (notesMode) {
      if (_board.cell(r, c) != 0) return; // заметки — только в пустых
      _pushHistory();
      final cellNotes = notesAt(r, c);
      cellNotes.contains(digit)
          ? cellNotes.remove(digit)
          : cellNotes.add(digit);
      notifyListeners();
      return;
    }

    _pushHistory();
    final next = _board.cell(r, c) == digit ? 0 : digit; // повтор = стереть
    _board = _board.withCell(r, c, next);
    notesAt(r, c).clear(); // цифра вытесняет заметки в своей клетке

    if (next != 0) {
      // Ошибка — это цифра, не совпадающая с решением. Конфликты
      // (дубль в строке) — отдельная, чисто визуальная подсветка.
      if (next != _puzzle.solution.cell(r, c)) errorCount++;
      _clearPeerNotes(r, c, next);
    }
    _checkFinished();
    notifyListeners();
  }

  void erase() {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null || isGiven(r, c) || isSolved || _paused) return;
    if (_board.cell(r, c) == 0 && notesAt(r, c).isEmpty) return; // нечего
    _pushHistory();
    _board = _board.withCell(r, c, 0);
    notesAt(r, c).clear();
    notifyListeners();
  }

  /// Подсказка: открыть правильную цифру в выбранной клетке.
  /// Решение головоломки генератор дал нам ещё на этапе 1 —
  /// вот и первое применение.
  void useHint() {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null || isGiven(r, c) || isSolved || _paused) return;
    if (hintsLeft <= 0) return;
    final correct = _puzzle.solution.cell(r, c);
    if (_board.cell(r, c) == correct) return; // уже верно — не тратим

    _pushHistory();
    hintsLeft--;
    _board = _board.withCell(r, c, correct);
    notesAt(r, c).clear();
    _clearPeerNotes(r, c, correct);
    _checkFinished();
    notifyListeners();
  }

  /// Отмена последнего хода. Счётчик ошибок сознательно НЕ откатываем:
  /// иначе связка «ошибся → undo» обнуляла бы цену ошибки. Ошибка —
  /// это событие («игрок ошибся»), а не часть позиции на доске.
  /// Потраченные подсказки не возвращаем по той же причине.
  void undo() {
    if (_history.isEmpty || isSolved || _paused) return;
    final snapshot = _history.removeLast();
    _board = snapshot.board;
    _notes = snapshot.notes;
    notifyListeners();
  }

  void togglePause() {
    if (isSolved) return;
    _paused = !_paused;
    _paused ? _stopwatch.stop() : _stopwatch.start();
    notifyListeners();
  }

  void newGame(Difficulty difficulty) {
    _puzzle = _generator.generate(difficulty);
    _board = _puzzle.puzzle;
    _notes = List.generate(cellCount, (_) => <int>{});
    _history.clear();
    selectedRow = null;
    selectedCol = null;
    notesMode = false;
    hintsLeft = hintsPerGame;
    errorCount = 0;
    _paused = false;
    _stopwatch
      ..reset()
      ..start();
    notifyListeners();
  }

  // ---------- Внутреннее ----------

  void _pushHistory() {
    // Заметки копируем вглубь: Set'ы изменяемые, и без копии снимок
    // «менялся бы задним числом» вместе с текущим состоянием.
    _history.add(_Snapshot(
      _board,
      [for (final s in _notes) Set<int>.from(s)],
    ));
  }

  /// Поставили цифру — убираем её из заметок строки, столбца и квадрата:
  /// кандидатом там она быть уже не может. Ровно то, что игрок делал бы
  /// ластиком вручную.
  void _clearPeerNotes(int row, int col, int digit) {
    for (int i = 0; i < boardSize; i++) {
      notesAt(row, i).remove(digit);
      notesAt(i, col).remove(digit);
    }
    final boxRow = (row ~/ boxSize) * boxSize;
    final boxCol = (col ~/ boxSize) * boxSize;
    for (int r = boxRow; r < boxRow + boxSize; r++) {
      for (int c = boxCol; c < boxCol + boxSize; c++) {
        notesAt(r, c).remove(digit);
      }
    }
  }

  void _checkFinished() {
    if (isSolved) _stopwatch.stop();
  }
}
