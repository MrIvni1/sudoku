/// Состояние текущей партии и операции над ним.
///
/// Этап 4: автосохранение через SaveRepository, восстановление партии
/// при запуске, статистика (победы, лучшее время, серии) и новая
/// настройка — подсветка строки/столбца/квадрата (по просьбе игрока).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/generator.dart';
import '../core/techniques.dart';
import '../data/game_save.dart';
import '../data/save_repository.dart';

class _Snapshot {
  final SudokuBoard board;
  final List<Set<int>> notes;
  const _Snapshot(this.board, this.notes);
}

class GameController extends ChangeNotifier {
  static const int hintsPerGame = 3;

  final SudokuGenerator _generator = SudokuGenerator();
  final SaveRepository _repository;

  late GeneratedPuzzle _puzzle;
  late SudokuBoard _board;
  late List<Set<int>> _notes;
  late GameStats stats;

  final List<_Snapshot> _history = [];

  int? selectedRow;
  int? selectedCol;
  bool notesMode = false;
  bool highlightConflicts = true;
  bool highlightPeers = true; // подсветка строки/столбца/квадрата
  bool highlightSameDigit = true; // подсветка одинаковых цифр
  int hintsLeft = hintsPerGame;
  int errorCount = 0;

  /// Последняя умная подсказка: пока не null, экран показывает карточку
  /// с объяснением, а поле подсвечивает клетки-«виновники».
  /// Сбрасывается любым следующим действием игрока.
  TechniqueHint? activeHint;

  final Stopwatch _stopwatch = Stopwatch();

  /// Stopwatch нельзя «завести» с нужного значения, поэтому время из
  /// сохранения храним отдельным слагаемым: elapsed = офсет + секундомер.
  Duration _elapsedOffset = Duration.zero;

  Timer? _ticker;
  int _tickCount = 0;
  bool _paused = false;

  GameController(this._repository) {
    stats = _repository.loadStats();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stopwatch.isRunning) {
        // Время партии тоже часть сохранения, но писать на диск каждую
        // секунду расточительно — пишем раз в 10 секунд. При любом ходе
        // игрока сохранение и так происходит сразу.
        if (++_tickCount % 10 == 0) _persist();
        notifyListeners();
      }
    });
    if (!_tryRestore()) {
      newGame(Difficulty.easy);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------- Чтение состояния (для виджетов) ----------

  SudokuBoard get board => _board;
  Difficulty get difficulty => _puzzle.difficulty;
  bool get isSolved => _board.isSolved;
  bool get isPaused => _paused;
  bool get canUndo => _history.isNotEmpty;
  Duration get elapsed => _elapsedOffset + _stopwatch.elapsed;

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

  /// Партия «начата»: игрок сделал хоть один ход относительно исходной
  /// головоломки. Нужно для честного подсчёта серий.
  bool get _hasProgress =>
      !listEquals(_board.toMutableList(), _puzzle.puzzle.toMutableList());

  // ---------- Действия игрока ----------

  void select(int row, int col) {
    if (_paused) return;
    activeHint = null; // любое действие закрывает объяснение
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

  void toggleHighlightPeers() {
    highlightPeers = !highlightPeers;
    notifyListeners();
  }

  void toggleHighlightSameDigit() {
    highlightSameDigit = !highlightSameDigit;
    notifyListeners();
  }

  void dismissHint() {
    activeHint = null;
    notifyListeners();
  }

  void input(int digit) {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null || isGiven(r, c) || isSolved || _paused) return;

    activeHint = null;
    if (notesMode) {
      if (_board.cell(r, c) != 0) return;
      _pushHistory();
      final cellNotes = notesAt(r, c);
      cellNotes.contains(digit)
          ? cellNotes.remove(digit)
          : cellNotes.add(digit);
      _persist();
      notifyListeners();
      return;
    }

    _pushHistory();
    final next = _board.cell(r, c) == digit ? 0 : digit;
    _board = _board.withCell(r, c, next);
    notesAt(r, c).clear();

    if (next != 0) {
      if (next != _puzzle.solution.cell(r, c)) errorCount++;
      _clearPeerNotes(r, c, next);
    }
    _checkFinished();
    _persist();
    notifyListeners();
  }

  void erase() {
    final r = selectedRow, c = selectedCol;
    if (r == null || c == null || isGiven(r, c) || isSolved || _paused) return;
    if (_board.cell(r, c) == 0 && notesAt(r, c).isEmpty) return;
    activeHint = null;
    _pushHistory();
    _board = _board.withCell(r, c, 0);
    notesAt(r, c).clear();
    _persist();
    notifyListeners();
  }

  /// Умная подсказка. Сначала пытаемся найти ЛОГИЧЕСКИЙ ход техниками
  /// (naked/hidden single) — тогда игрок получает и цифру, и объяснение,
  /// и подсветку клеток, из-за которых вывод верен. Если техники
  /// бессильны (или позиция «отравлена» ошибками игрока) — честный
  /// fallback: просто открыть правильную цифру, как раньше.
  void useHint() {
    if (isSolved || _paused || hintsLeft <= 0) return;

    // 1) Логический ход. На доске с конфликтами техники не запускаем:
    // их выводы опираются на корректность позиции.
    TechniqueHint? found;
    if (!_board.hasConflicts) {
      found = TechniqueFinder.find(_board);
      // Ошибочные (но не конфликтующие) цифры игрока могли увести
      // позицию от настоящего решения — сверяем вывод техники с ним.
      if (found != null &&
          _puzzle.solution.cell(found.row, found.col) != found.value) {
        found = null;
      }
    }

    if (found != null) {
      _pushHistory();
      hintsLeft--;
      selectedRow = found.row;
      selectedCol = found.col;
      _board = _board.withCell(found.row, found.col, found.value);
      notesAt(found.row, found.col).clear();
      _clearPeerNotes(found.row, found.col, found.value);
      activeHint = found;
      _checkFinished();
      _persist();
      notifyListeners();
      return;
    }

    // 2) Fallback: открыть цифру в выбранной клетке (или первой неверной).
    var r = selectedRow, c = selectedCol;
    final needsPick = r == null ||
        c == null ||
        isGiven(r, c) ||
        _board.cell(r, c) == _puzzle.solution.cell(r, c);
    if (needsPick) {
      (r, c) = (null, null);
      outer:
      for (int i = 0; i < boardSize; i++) {
        for (int j = 0; j < boardSize; j++) {
          if (!isGiven(i, j) &&
              _board.cell(i, j) != _puzzle.solution.cell(i, j)) {
            (r, c) = (i, j);
            break outer;
          }
        }
      }
    }
    if (r == null || c == null) return; // всё уже верно

    final correct = _puzzle.solution.cell(r, c);
    _pushHistory();
    hintsLeft--;
    selectedRow = r;
    selectedCol = c;
    _board = _board.withCell(r, c, correct);
    notesAt(r, c).clear();
    _clearPeerNotes(r, c, correct);
    activeHint = null;
    _checkFinished();
    _persist();
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty || isSolved || _paused) return;
    activeHint = null;
    final snapshot = _history.removeLast();
    _board = snapshot.board;
    _notes = snapshot.notes;
    _persist();
    notifyListeners();
  }

  void togglePause() {
    if (isSolved) return;
    activeHint = null;
    _paused = !_paused;
    _paused ? _stopwatch.stop() : _stopwatch.start();
    _persist();
    notifyListeners();
  }

  void newGame(Difficulty difficulty) {
    // Бросили начатую партию — серия побед обрывается.
    // (В конструкторе _puzzle ещё не создана — тогда и рвать нечего.)
    try {
      if (_hasProgress && !isSolved) {
        stats.recordAbandon();
        _repository.saveStats(stats);
      }
    } catch (_) {
      // первая инициализация, _puzzle ещё нет — это нормально
    }

    _puzzle = _generator.generate(difficulty);
    _board = _puzzle.puzzle;
    _notes = List.generate(cellCount, (_) => <int>{});
    activeHint = null;
    _history.clear();
    selectedRow = null;
    selectedCol = null;
    notesMode = false;
    hintsLeft = hintsPerGame;
    errorCount = 0;
    _paused = false;
    _elapsedOffset = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _persist();
    notifyListeners();
  }

  // ---------- Сохранение и восстановление ----------

  /// Попытка продолжить сохранённую партию. Возвращаемся в состоянии
  /// паузы — пусть игрок осмотрится и сам нажмёт «продолжить»,
  /// а не обнаружит тикающий таймер.
  bool _tryRestore() {
    final save = _repository.loadGame();
    if (save == null) return false;
    try {
      _puzzle = GeneratedPuzzle(
        puzzle: SudokuBoard.fromList(save.puzzle),
        solution: SudokuBoard.fromList(save.solution),
        difficulty: Difficulty.values[save.difficultyIndex],
      );
      _board = SudokuBoard.fromList(save.board);
      _notes = [for (final cell in save.notes) Set<int>.from(cell)];
      hintsLeft = save.hintsLeft;
      errorCount = save.errorCount;
      _elapsedOffset = Duration(seconds: save.elapsedSeconds);
      _stopwatch.reset();
      _paused = true;
      notifyListeners();
      return true;
    } catch (_) {
      // Битое сохранение (SudokuBoard.fromList бросил исключение и т.п.)
      _repository.clearGame();
      return false;
    }
  }

  void _persist() {
    if (isSolved) return; // решённые партии не храним — их место в статистике
    _repository.saveGame(GameSave(
      puzzle: _puzzle.puzzle.toMutableList(),
      solution: _puzzle.solution.toMutableList(),
      board: _board.toMutableList(),
      notes: [for (final s in _notes) s.toList()..sort()],
      difficultyIndex: difficulty.index,
      elapsedSeconds: elapsed.inSeconds,
      hintsLeft: hintsLeft,
      errorCount: errorCount,
    ));
  }

  // ---------- Внутреннее ----------

  void _pushHistory() {
    _history.add(_Snapshot(
      _board,
      [for (final s in _notes) Set<int>.from(s)],
    ));
  }

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
    if (!isSolved) return;
    _stopwatch.stop();
    stats.recordWin(difficulty.name, elapsed.inSeconds);
    _repository.saveStats(stats);
    _repository.clearGame(); // партия окончена — сохранение больше не нужно
  }
}
