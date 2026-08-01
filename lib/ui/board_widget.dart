/// Отрисовка поля 9×9.
///
/// Этап 3: клетки научились показывать заметки (мини-сетка 3×3 с
/// кандидатами), прятаться на паузе и уважать настройку «подсвечивать
/// конфликты».
library;

import 'package:flutter/material.dart';

import '../core/board.dart';
import 'game_controller.dart';

class BoardWidget extends StatelessWidget {
  final GameController controller;

  const BoardWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.onSurface, width: 2),
        ),
        child: Column(
          children: [
            for (int row = 0; row < boardSize; row++)
              Expanded(
                child: Row(
                  children: [
                    for (int col = 0; col < boardSize; col++)
                      Expanded(
                          child: _Cell(
                              controller: controller, row: row, col: col)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final GameController controller;
  final int row;
  final int col;

  const _Cell({required this.controller, required this.row, required this.col});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // На паузе поле «зашторено»: ни цифр, ни заметок, ни выделений —
    // чтобы нельзя было разглядывать позицию с остановленным таймером.
    if (controller.isPaused) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: _border(colors),
        ),
      );
    }

    final value = controller.board.cell(row, col);
    final notes = controller.notesAt(row, col);

    final isSelected =
        controller.selectedRow == row && controller.selectedCol == col;
    // Подсветка строки/столбца/квадрата — по настройке (этап 4).
    final isPeer =
        controller.highlightPeers && controller.isPeerOfSelection(row, col);
    final sameDigit =
        value != 0 && value == controller.selectedValue && !isSelected;
    // Конфликт вычисляется всегда, а вот показывается — по настройке.
    final isConflict =
        controller.highlightConflicts && controller.isConflict(row, col);
    final isGiven = controller.isGiven(row, col);

    final Color background;
    if (isSelected) {
      background = colors.primaryContainer;
    } else if (sameDigit) {
      background = colors.secondaryContainer;
    } else if (isPeer) {
      background = colors.surfaceContainerHighest;
    } else {
      background = colors.surface;
    }

    final Color digitColor;
    if (isConflict) {
      digitColor = colors.error;
    } else if (isGiven) {
      digitColor = colors.onSurface;
    } else {
      digitColor = colors.primary;
    }

    final Widget? content;
    if (value != 0) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              color: digitColor,
              fontWeight: isGiven ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    } else if (notes.isNotEmpty) {
      content = _NotesGrid(notes: notes, color: colors.onSurfaceVariant);
    } else {
      content = null;
    }

    return GestureDetector(
      onTap: () => controller.select(row, col),
      child: Container(
        decoration: BoxDecoration(color: background, border: _border(colors)),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }

  Border _border(ColorScheme colors) {
    final thin = BorderSide(color: colors.outlineVariant, width: 0.5);
    final thick = BorderSide(color: colors.onSurface, width: 1.8);
    final isThickRight = (col + 1) % boxSize == 0 && col != boardSize - 1;
    final isThickBottom = (row + 1) % boxSize == 0 && row != boardSize - 1;
    return Border(
      right: col == boardSize - 1
          ? BorderSide.none
          : (isThickRight ? thick : thin),
      bottom: row == boardSize - 1
          ? BorderSide.none
          : (isThickBottom ? thick : thin),
    );
  }
}

/// Мини-сетка 3×3 с кандидатами. Каждая цифра всегда на «своём» месте:
/// 1 — левый верхний угол, 5 — центр, 9 — правый нижний. Так глаз игрока
/// находит кандидата мгновенно, не читая клетку целиком.
class _NotesGrid extends StatelessWidget {
  final Set<int> notes;
  final Color color;

  const _NotesGrid({required this.notes, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          for (int r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (int c = 0; c < 3; c++)
                    Expanded(
                      child: Center(
                        child: notes.contains(r * 3 + c + 1)
                            ? FittedBox(
                                child: Text(
                                  '${r * 3 + c + 1}',
                                  style: TextStyle(fontSize: 10, color: color),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
