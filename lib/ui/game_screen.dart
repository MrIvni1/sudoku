/// Главный экран: поле + панель ввода + меню новой игры.
///
/// Здесь живут два важных механизма:
///
/// 1. ListenableBuilder слушает GameController: любое notifyListeners()
///    перерисовывает всё, что внутри builder. Для доски из 81 клетки
///    это дёшево — Flutter перерисовывает виджеты, а не пиксели.
///
/// 2. LayoutBuilder даёт доступную ширину: на узком экране (телефон)
///    поле сверху, кнопки снизу; на широком (web, планшет) — рядом.
library;

import 'package:flutter/material.dart';

import '../../core/generator.dart';
import 'board_widget.dart';
import 'game_controller.dart';
import 'input_panel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Контроллер создаётся один раз и живёт, пока жив экран.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Судоку'),
        actions: [
          // Меню «новая игра» с выбором сложности.
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
                    child: BoardWidget(controller: _controller),
                  ),
                );
                final panel = Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _difficultyNames[_controller.difficulty]!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
          Text('Решено!',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: colors.onPrimaryContainer)),
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
