/// Модели сохранения: снимок партии и статистика.
///
/// Ключевое решение: это ЧИСТЫЙ Dart без Flutter и без hive. Модели
/// умеют превращаться в JSON и обратно — и всё. Куда этот JSON ляжет
/// (hive, файл, сервер) — забота репозитория. Благодаря этому
/// сериализацию можно тестировать обычными unit-тестами без запуска
/// приложения (см. test/save_test.dart).
library;

import 'dart:convert';

/// Снимок текущей партии — всё, что нужно, чтобы продолжить с того же
/// места. История undo сознательно не сохраняется: это упрощение,
/// цена которого — «после перезапуска нельзя отменить старые ходы».
/// Для судоку это честный компромисс.
class GameSave {
  final List<int> puzzle; // исходные подсказки
  final List<int> solution; // решение (для проверок и подсказок)
  final List<int> board; // текущее состояние с ходами игрока
  final List<List<int>> notes; // заметки: список кандидатов на клетку
  final int difficultyIndex;
  final int elapsedSeconds;
  final int hintsLeft;
  final int errorCount;

  const GameSave({
    required this.puzzle,
    required this.solution,
    required this.board,
    required this.notes,
    required this.difficultyIndex,
    required this.elapsedSeconds,
    required this.hintsLeft,
    required this.errorCount,
  });

  Map<String, dynamic> toMap() => {
        'puzzle': puzzle,
        'solution': solution,
        'board': board,
        'notes': notes,
        'difficulty': difficultyIndex,
        'elapsed': elapsedSeconds,
        'hints': hintsLeft,
        'errors': errorCount,
      };

  /// Может бросить исключение на битых данных — вызывающий код обязан
  /// это учитывать (у нас: битое сохранение = начинаем новую игру).
  factory GameSave.fromMap(Map<String, dynamic> map) => GameSave(
        puzzle: List<int>.from(map['puzzle'] as List),
        solution: List<int>.from(map['solution'] as List),
        board: List<int>.from(map['board'] as List),
        notes: [
          for (final cell in map['notes'] as List) List<int>.from(cell as List)
        ],
        difficultyIndex: map['difficulty'] as int,
        elapsedSeconds: map['elapsed'] as int,
        hintsLeft: map['hints'] as int,
        errorCount: map['errors'] as int,
      );

  String toJson() => jsonEncode(toMap());

  factory GameSave.fromJson(String source) =>
      GameSave.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Статистика по одному уровню сложности.
class DifficultyStats {
  int wins;
  int? bestTimeSeconds; // null = ещё ни одной победы

  DifficultyStats({this.wins = 0, this.bestTimeSeconds});

  Map<String, dynamic> toMap() => {'wins': wins, 'best': bestTimeSeconds};

  factory DifficultyStats.fromMap(Map<String, dynamic> map) => DifficultyStats(
        wins: map['wins'] as int? ?? 0,
        bestTimeSeconds: map['best'] as int?,
      );
}

/// Общая статистика: по уровням + серии побед.
///
/// Серия — это подряд выигранные партии. Рвётся, если бросить начатую
/// партию (начать новую, не решив текущую).
class GameStats {
  final Map<String, DifficultyStats> byDifficulty; // ключ — имя уровня
  int currentStreak;
  int bestStreak;

  GameStats({
    Map<String, DifficultyStats>? byDifficulty,
    this.currentStreak = 0,
    this.bestStreak = 0,
  }) : byDifficulty = byDifficulty ?? {};

  DifficultyStats statsFor(String difficultyName) =>
      byDifficulty.putIfAbsent(difficultyName, () => DifficultyStats());

  void recordWin(String difficultyName, int timeSeconds) {
    final stats = statsFor(difficultyName);
    stats.wins++;
    if (stats.bestTimeSeconds == null || timeSeconds < stats.bestTimeSeconds!) {
      stats.bestTimeSeconds = timeSeconds;
    }
    currentStreak++;
    if (currentStreak > bestStreak) bestStreak = currentStreak;
  }

  void recordAbandon() {
    currentStreak = 0;
  }

  String toJson() => jsonEncode({
        'byDifficulty': {
          for (final e in byDifficulty.entries) e.key: e.value.toMap()
        },
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
      });

  factory GameStats.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return GameStats(
      byDifficulty: {
        for (final e in (map['byDifficulty'] as Map<String, dynamic>).entries)
          e.key: DifficultyStats.fromMap(e.value as Map<String, dynamic>)
      },
      currentStreak: map['currentStreak'] as int? ?? 0,
      bestStreak: map['bestStreak'] as int? ?? 0,
    );
  }
}
