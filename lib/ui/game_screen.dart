/// Главный экран. Этап 4: принимает SaveRepository и передаёт его
/// контроллеру, показывает статистику, в настройках — второй
/// переключатель (подсветка строки/столбца/квадрата).
library;

import 'package:flutter/material.dart';

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

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller = GameController(widget.repository);

  static const _difficultyNames = {
    Difficulty.easy: 'Лёгкий',
    Difficulty.medium: 'Средний',
    Difficulty.hard: 'Сложный',
    Difficulty.expert: 'Эксперт',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
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
                        BoardWidget(controller: _controller),
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
                        _victoryBanner(context),
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
    );
  }

  /// Карточка с объяснением умной подсказки. Клетки-«виновники»
  /// в этот момент подсвечены на поле третьим цветом.
  Widget _hintCard(BuildContext context) {
    final hint = _controller.activeHint!;
    final colors = Theme.of(context).colorScheme;
    const techniqueNames = {
      'naked_single': 'Единственный кандидат',
      'hidden_single': 'Единственное место',
    };
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
                  techniqueNames[hint.technique] ?? hint.technique,
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
