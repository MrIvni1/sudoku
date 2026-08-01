/// Главный экран. Новое: ввод с клавиатуры (web/десктоп), анимация
/// победы (волна по полю + появление баннера), индикаторы генерации.
///
/// Клавиши: 1–9 — цифры, 0/Backspace/Delete — стереть, стрелки —
/// перемещение по полю, N — заметки, H — подсказка, P/пробел — пауза,
/// Z — отмена хода.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/generator.dart';
import '../data/save_repository.dart';
import 'board_widget.dart';
import 'game_controller.dart';
import 'input_panel.dart';

class GameScreen extends StatefulWidget {
  final SaveRepository repository;

  const GameScreen({super.key, required this.repository});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _controller = GameController(widget.repository);

  /// Контроллер анимации победы. AnimationController — «ручной» механизм
  /// Flutter: тикает от 0 до 1 за duration, а AnimatedBuilder ниже
  /// перерисовывает поле на каждом тике.
  late final AnimationController _victoryAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _wasSolved = false;

  static const _difficultyNames = {
    Difficulty.easy: 'Лёгкий',
    Difficulty.medium: 'Средний',
    Difficulty.hard: 'Сложный',
    Difficulty.expert: 'Эксперт',
  };

  static const _techniqueNames = {
    'naked_single': 'Единственный кандидат',
    'hidden_single': 'Единственное место',
    'naked_pair': 'Голая пара',
    'pointing_pair': 'Указывающая пара',
    'x_wing': 'X-wing',
  };

  @override
  void initState() {
    super.initState();
    // Ловим момент перехода «не решено -> решено» и запускаем анимацию.
    _controller.addListener(_onGameChanged);
  }

  void _onGameChanged() {
    final solved = _controller.isSolved;
    if (solved && !_wasSolved) _victoryAnim.forward(from: 0);
    _wasSolved = solved;
  }

  @override
  void dispose() {
    _controller.removeListener(_onGameChanged);
    _victoryAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------- Клавиатура ----------

  static final _digitKeys = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad9: 9,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    final digit = _digitKeys[key];
    if (digit != null) {
      _controller.input(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
      _controller.erase();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _controller.moveSelection(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _controller.moveSelection(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _controller.moveSelection(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _controller.moveSelection(0, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN) {
      _controller.toggleNotesMode();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      _controller.useHint();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP || key == LogicalKeyboardKey.space) {
      _controller.togglePause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      _controller.undo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------- Вёрстка ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Судоку'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Статистика',
            onPressed: _showStats,
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                checked: _controller.highlightConflicts,
                onTap: _controller.toggleHighlightConflicts,
                child: const Text('Подсвечивать конфликты'),
              ),
              CheckedPopupMenuItem(
                checked: _controller.highlightPeers,
                onTap: _controller.toggleHighlightPeers,
                child: const Text('Подсвечивать строку и квадрат'),
              ),
              CheckedPopupMenuItem(
                checked: _controller.highlightSameDigit,
                onTap: _controller.toggleHighlightSameDigit,
                child: const Text('Подсвечивать одинаковые цифры'),
              ),
            ],
          ),
          PopupMenuButton<Difficulty>(
            icon: const Icon(Icons.add),
            tooltip: 'Новая игра',
            onSelected: _controller.newGame,
            itemBuilder: (context) => [
              for (final d in Difficulty.values)
                PopupMenuItem(value: d, child: Text(_difficultyNames[d]!)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        // Focus + autofocus: экран сразу слушает клавиатуру, без кликов.
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              // Первый запуск: партия ещё генерируется — показываем
              // заглушку вместо всего экрана.
              if (!_controller.isReady) {
                return const Center(child: CircularProgressIndicator());
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 600;

                  final board = Padding(
                    padding: const EdgeInsets.all(12),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 560, maxHeight: 560),
                      child: Stack(
                        children: [
                          // AnimatedBuilder перерисовывает поле на каждом
                          // тике анимации победы (а вне её — victory = 0
                          // и поле рисуется как обычно).
                          AnimatedBuilder(
                            animation: _victoryAnim,
                            builder: (context, _) => BoardWidget(
                              controller: _controller,
                              victory:
                                  _controller.isSolved ? _victoryAnim.value : 0,
                            ),
                          ),
                          if (_controller.isPaused)
                            Positioned.fill(
                              child: Center(
                                child: FilledButton.icon(
                                  onPressed: _controller.togglePause,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Продолжить'),
                                ),
                              ),
                            ),
                          // Смена сложности: старое поле + вуаль загрузки.
                          if (_controller.isGenerating)
                            Positioned.fill(
                              child: ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withOpacity(0.7),
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );

                  final panel = Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _statusRow(context),
                        const SizedBox(height: 16),
                        if (_controller.activeHint != null) ...[
                          _hintCard(context),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: 340,
                          child: InputPanel(controller: _controller),
                        ),
                        if (_controller.isSolved) ...[
                          const SizedBox(height: 24),
                          // Баннер выпрыгивает в конце волны по полю.
                          ScaleTransition(
                            scale: CurvedAnimation(
                              parent: _victoryAnim,
                              curve: const Interval(0.45, 1,
                                  curve: Curves.easeOutBack),
                            ),
                            child: _victoryBanner(context),
                          ),
                        ],
                      ],
                    ),
                  );

                  return wide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Flexible(child: board), panel],
                        )
                      : Column(
                          children: [Flexible(child: board), panel],
                        );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hintCard(BuildContext context) {
    final hint = _controller.activeHint!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb,
                  size: 18, color: colors.onTertiaryContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _techniqueNames[hint.technique] ?? hint.technique,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onTertiaryContainer,
                  ),
                ),
              ),
              InkWell(
                onTap: _controller.dismissHint,
                child: Icon(Icons.close,
                    size: 18, color: colors.onTertiaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint.explanation,
            style: TextStyle(color: colors.onTertiaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_difficultyNames[_controller.difficulty]!, style: style),
        const SizedBox(width: 16),
        Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.error),
        Text(' ${_controller.errorCount}', style: style),
        const SizedBox(width: 16),
        Text(_formatTime(_controller.elapsed), style: style),
        IconButton(
          onPressed: _controller.isSolved ? null : _controller.togglePause,
          tooltip: _controller.isPaused ? 'Продолжить' : 'Пауза',
          icon: Icon(_controller.isPaused ? Icons.play_arrow : Icons.pause),
        ),
      ],
    );
  }

  Widget _victoryBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('Решено за ${_formatTime(_controller.elapsed)}!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: colors.onPrimaryContainer)),
          Text('Ошибок: ${_controller.errorCount}',
              style: TextStyle(color: colors.onPrimaryContainer)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _controller.newGame(_controller.difficulty),
            child: const Text('Новая игра'),
          ),
        ],
      ),
    );
  }

  void _showStats() {
    final stats = _controller.stats;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Статистика'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in Difficulty.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(builder: (context) {
                  final s = stats.statsFor(d.name);
                  final best = s.bestTimeSeconds;
                  return Text(
                    '${_difficultyNames[d]}: побед ${s.wins}'
                    '${best != null ? ', лучшее время ${_formatTime(Duration(seconds: best))}' : ''}',
                  );
                }),
              ),
            const Divider(),
            Text('Текущая серия: ${stats.currentStreak}'),
            Text('Лучшая серия: ${stats.bestStreak}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
