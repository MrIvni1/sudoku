/// Состояние текущей партии и операции над ним.
///
/// Новое на этом шаге: генерация уехала в отдельный Isolate (compute),
/// поэтому newGame стал асинхронным и появились флаги isReady /
/// isGenerating; добавлено перемещение выбора стрелками (для клавиатуры).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/generator.dart';
import '../core/techniques.dart';
import '../data/game_save.dart';
import '../data/save_repository.dart';

/// Задача для Isolate. По правилам compute это должна быть функция
/// верхнего уровня (или статическая): Isolate не может забрать с собой
/// замыкание с контекстом — только чистую функцию и сообщение.
GeneratedPuzzle _generatePuzzleTask(Difficulty difficulty) =>
    SudokuGenerator().generate(difficulty);

class _Snapshot {
  final SudokuBoard board;
  final List<Set<int>> notes;
  const _Snapshot(this.board, this.notes);
}

class GameController extends ChangeNotifier {
  static const int hintsPerGame = 3;

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
  bool highlightPeers = true;
  bool highlightSameDigit = true;
  int hintsLeft = hintsPerGame;
  int errorCount = 0;

  TechniqueHint? activeHint;

  /// Партия загружена и готова к показу. До первого newGame/restore —
  /// false, и UI обязан показывать заглушку, не трогая board.
  bool _ready = false;
  bool get isReady => _ready;

  /// Идёт фоновая генерация новой головоломки.
  bool isGenerating = false;

  final Stopwatch _stopwatch = Stopwatch();
  Duration _elapsedOffset = Duration.zero;
  Timer? _ticker;
  int _tickCount = 0;
  bool _paused = false;

  GameController(this._repository) {
    stats = _repository.loadStats();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_stopwatch.isRunning) {
        if (++_tickCount % 10 == 0) _persist();
        notifyListeners();
      }
    });
    if (!_tryRestore()) {
      unawaited(newGame(Difficulty.easy));
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
  bool get isSolved => _ready && _board.isSolved;
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

  bool get _hasProgress =>
      !listEquals(_board.toMutableList(), _puzzle.puzzle.toMutableList());

  // ---------- Действия игрока ----------

  void select(int row, int col) {
    if (_paused || !_ready) return;
    activeHint = null;
    selectedRow = row;
    selectedCol = col;
    notifyListeners();
  }

  /// Перемещение выбора стрелками (клавиатура на web/десктопе).
  /// Если ничего не выбрано — встаём в левый верхний угол.
  void moveSelection(int dRow, int dCol) {
    if (_paused || !_ready) return;
    activeHint = null;
    if (selectedRow == null || selectedCol == null) {
      selectedRow = 0;
      selectedCol = 0;
    } else {
      selectedRow = (selectedRow! + dRow).clamp(0, boardSize - 1);
      selectedCol = (selectedCol! + dCol).clamp(0, boardSize - 1);
    }
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
    if (!_ready || r == null || c == null) return;
    if (isGiven(r, c) || isSolved || _paused) return;

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
    if (!_ready || r == null || c == null) return;
    if (isGiven(r, c) || isSolved || _paused) return;
    if (_board.cell(r, c) == 0 && notesAt(r, c).isEmpty) return;
    activeHint = null;
    _pushHistory();
    _board = _board.withCell(r, c, 0);
    notesAt(r, c).clear();
    _persist();
    notifyListeners();
  }

  /// Умная подсказка: логический ход с объяснением; fallback — открыть
  /// правильную цифру.
  void useHint() {
    if (!_ready || isSolved || _paused || hintsLeft <= 0) return;

    TechniqueHint? found = TechniqueFinder.find(_board);
    // Ошибочные (но не конфликтующие) цифры игрока могли увести позицию
    // от настоящего решения — сверяем вывод техники с ним.
    if (found != null &&
        _puzzle.solution.cell(found.row, found.col) != found.value) {
      found = null;
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

    // Fallback: выбранная клетка или первая неверная.
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
    if (r == null || c == null) return;

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
    if (!_ready || _history.isEmpty || isSolved || _paused) return;
    activeHint = null;
    final snapshot = _history.removeLast();
    _board = snapshot.board;
    _notes = snapshot.notes;
    _persist();
    notifyListeners();
  }

  void togglePause() {
    if (!_ready || isSolved) return;
    activeHint = null;
    _paused = !_paused;
    _paused ? _stopwatch.stop() : _stopwatch.start();
    _persist();
    notifyListeners();
  }

  /// Новая партия. Генерация выполняется в отдельном Isolate через
  /// compute(): UI-поток свободен, интерфейс не замирает даже если
  /// экспертная доска решит посопротивляться. На web compute выполнится
  /// в основном потоке (изолятов там нет) — для наших миллисекунд ок.
  Future<void> newGame(Difficulty difficulty) async {
    if (isGenerating) return;

    if (_ready && _hasProgress && !isSolved) {
      stats.recordAbandon();
      await _repository.saveStats(stats);
    }

    isGenerating = true;
    notifyListeners();

    final puzzle = await compute(_generatePuzzleTask, difficulty);

    _puzzle = puzzle;
    _board = _puzzle.puzzle;
    _notes = List.generate(cellCount, (_) => <int>{});
    _history.clear();
    activeHint = null;
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
    isGenerating = false;
    _ready = true;
    _persist();
    notifyListeners();
  }

  // ---------- Сохранение и восстановление ----------

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
      _ready = true;
      notifyListeners();
      return true;
    } catch (_) {
      _repository.clearGame();
      return false;
    }
  }

  void _persist() {
    if (!_ready || isSolved) return;
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
    _repository.clearGame();
  }
}
