/// Модель доски судоку. Чистый Dart, без зависимостей от Flutter.
///
/// Ключевое решение: доска хранится как плоский список из 81 числа
/// (0 = пустая клетка, 1–9 = цифра). Плоский список проще копировать
/// и быстрее, чем список списков. Индекс клетки: index = row * 9 + col.
library;

/// Размер доски (9×9) и квадрата (3×3).
const int boardSize = 9;
const int boxSize = 3;
const int cellCount = boardSize * boardSize; // 81

/// Неизменяемая (immutable) доска судоку.
///
/// Ключевое решение: любое изменение создаёт НОВЫЙ объект доски
/// (метод [withCell]). Это делает undo тривиальным — достаточно
/// хранить список прошлых состояний, ничего не «испортится» по ссылке.
class SudokuBoard {
  final List<int> _cells;

  /// Приватный конструктор — принимает уже готовый список.
  const SudokuBoard._(this._cells);

  /// Пустая доска.
  factory SudokuBoard.empty() =>
      SudokuBoard._(List<int>.filled(cellCount, 0));

  /// Доска из списка (копируем, чтобы никто не менял её снаружи).
  factory SudokuBoard.fromList(List<int> cells) {
    if (cells.length != cellCount) {
      throw ArgumentError('Ожидается $cellCount клеток, получено ${cells.length}');
    }
    for (final v in cells) {
      if (v < 0 || v > 9) {
        throw ArgumentError('Недопустимое значение клетки: $v');
      }
    }
    return SudokuBoard._(List<int>.from(cells));
  }

  /// Значение клетки (row, col — от 0 до 8).
  int cell(int row, int col) => _cells[row * boardSize + col];

  /// Значение клетки по плоскому индексу (0–80).
  int cellAt(int index) => _cells[index];

  /// Копия внутреннего списка — для передачи в решатель,
  /// который работает с изменяемым списком ради скорости.
  List<int> toMutableList() => List<int>.from(_cells);

  /// Новая доска, где клетка (row, col) заменена на [value].
  /// value = 0 означает стирание.
  SudokuBoard withCell(int row, int col, int value) {
    assert(value >= 0 && value <= 9);
    final copy = List<int>.from(_cells);
    copy[row * boardSize + col] = value;
    return SudokuBoard._(copy);
  }

  /// Сколько клеток заполнено (это же — количество подсказок в головоломке).
  int get filledCount => _cells.where((v) => v != 0).length;

  /// Все ли клетки заполнены (без проверки правильности).
  bool get isFull => _cells.every((v) => v != 0);

  /// Можно ли поставить [value] в (row, col) по правилам судоку:
  /// в строке, столбце и квадрате 3×3 такой цифры ещё нет.
  /// Сама клетка при проверке игнорируется (удобно для перезаписи).
  bool isValidPlacement(int row, int col, int value) {
    if (value == 0) return true;
    for (int i = 0; i < boardSize; i++) {
      // строка
      if (i != col && cell(row, i) == value) return false;
      // столбец
      if (i != row && cell(i, col) == value) return false;
    }
    // квадрат 3×3: находим его левый верхний угол
    final boxRow = (row ~/ boxSize) * boxSize;
    final boxCol = (col ~/ boxSize) * boxSize;
    for (int r = boxRow; r < boxRow + boxSize; r++) {
      for (int c = boxCol; c < boxCol + boxSize; c++) {
        if ((r != row || c != col) && cell(r, c) == value) return false;
      }
    }
    return true;
  }

  /// Есть ли на доске конфликты (одинаковые цифры в строке/столбце/квадрате).
  bool get hasConflicts {
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        final v = cell(row, col);
        if (v != 0 && !isValidPlacement(row, col, v)) return true;
      }
    }
    return false;
  }

  /// Доска полностью и правильно решена.
  bool get isSolved => isFull && !hasConflicts;

  /// Красивый вывод в консоль — пригодится для отладки и demo.
  @override
  String toString() {
    final sb = StringBuffer();
    for (int row = 0; row < boardSize; row++) {
      if (row % boxSize == 0 && row != 0) {
        sb.writeln('------+-------+------');
      }
      for (int col = 0; col < boardSize; col++) {
        if (col % boxSize == 0 && col != 0) sb.write('| ');
        final v = cell(row, col);
        sb.write(v == 0 ? '. ' : '$v ');
      }
      sb.writeln();
    }
    return sb.toString();
  }
}