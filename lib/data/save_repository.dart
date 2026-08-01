/// Репозиторий сохранений: единственное место в приложении, знающее
/// про hive. Контроллер говорит «сохрани партию» / «дай статистику»,
/// а КАК это хранится — деталь, спрятанная здесь. Захотим сменить hive
/// на что-то другое — перепишем один этот файл.
///
/// Почему hive: чистый Dart (работает на iOS/Android/web без нативного
/// кода), быстрый, данные лежат локально на устройстве — ровно наш
/// офлайн-сценарий. На web под капотом IndexedDB браузера.
library;

import 'package:hive/hive.dart';

import 'game_save.dart';

class SaveRepository {
  static const _gameKey = 'currentGame';
  static const _statsKey = 'stats';

  /// Box — это «ящик» hive, по сути персистентный Map<String, String>.
  /// Мы храним значения строками (JSON): просто и переносимо.
  final Box<String> _box;

  SaveRepository(this._box);

  // ---------- Текущая партия ----------

  Future<void> saveGame(GameSave save) => _box.put(_gameKey, save.toJson());

  Future<void> clearGame() => _box.delete(_gameKey);

  /// null — сохранения нет ИЛИ оно не читается. Битое сохранение
  /// молча выбрасываем: потерять партию неприятно, но зависнуть
  /// на старте приложения — гораздо хуже.
  GameSave? loadGame() {
    final raw = _box.get(_gameKey);
    if (raw == null) return null;
    try {
      return GameSave.fromJson(raw);
    } catch (_) {
      _box.delete(_gameKey);
      return null;
    }
  }

  // ---------- Статистика ----------

  Future<void> saveStats(GameStats stats) => _box.put(_statsKey, stats.toJson());

  GameStats loadStats() {
    final raw = _box.get(_statsKey);
    if (raw == null) return GameStats();
    try {
      return GameStats.fromJson(raw);
    } catch (_) {
      return GameStats();
    }
  }
}
