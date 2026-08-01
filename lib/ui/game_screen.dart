/// Главный экран: поле + панель ввода + строка статуса (таймер, ошибки)
/// + пауза и настройки.
library;

import 'package:flutter/material.dart';

import '../core/generator.dart';
import 'board_widget.dart';
import 'game_controller.dart';
import 'input_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController _controller = GameController();

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

  /// 65 секунд -> «01:05». У Duration нет готового форматирования,
  /// поэтому собираем строку сами.
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
          // Настройки: пока одна — подсветка конфликтов.
          PopupMenuButton<void>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                checked: _controller.highlightConflicts,
                onTap: _controller.toggleHighlightConflicts,
                child: const Text('Подсвечивать конфликты'),
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

                // Поле + шторка паузы поверх него.
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

  /// Строка статуса: сложность · ошибки · таймер · пауза.
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
}
