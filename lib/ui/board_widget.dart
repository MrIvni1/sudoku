/// Отрисовка поля 9×9.
///
/// Устройство: Column из 9 Row, в каждой — 9 клеток через Expanded,
/// всё внутри AspectRatio(1.0), чтобы поле всегда было квадратным
/// и растягивалось под доступное место. Для 81 клетки этого достаточно;
/// CustomPaint понадобился бы для тысяч элементов, но не здесь.
///
/// Толстые линии между квадратами 3×3 сделаны через границы клеток:
/// каждая клетка рисует свою правую и нижнюю границу (тонкую или
/// толстую — если она третья по счёту), а внешнюю рамку рисует
/// общий контейнер. Так линии не «двоятся».
library;

import 'package:flutter/material.dart';

import '../../core/board.dart';
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
    final value = controller.board.cell(row, col);

    final isSelected =
        controller.selectedRow == row && controller.selectedCol == col;
    final isPeer = controller.isPeerOfSelection(row, col);
    // Подсветка «таких же цифр»: помогает игроку видеть, где уже стоит
    // цифра, которую он рассматривает.
    final sameDigit =
        value != 0 && value == controller.selectedValue && !isSelected;
    final isConflict = controller.isConflict(row, col);
    final isGiven = controller.isGiven(row, col);

    // Приоритет фонов: выбранная > та же цифра > соседи > обычная.
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

    // Цвет цифры: конфликт > подсказка > ход игрока.
    final Color digitColor;
    if (isConflict) {
      digitColor = colors.error;
    } else if (isGiven) {
      digitColor = colors.onSurface;
    } else {
      digitColor = colors.primary;
    }

    // Правая/нижняя граница: толстая на стыке квадратов 3×3.
    final thin = BorderSide(color: colors.outlineVariant, width: 0.5);
    final thick = BorderSide(color: colors.onSurface, width: 1.8);
    final isThickRight = (col + 1) % boxSize == 0 && col != boardSize - 1;
    final isThickBottom = (row + 1) % boxSize == 0 && row != boardSize - 1;

    return GestureDetector(
      onTap: () => controller.select(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: col == boardSize - 1
                ? BorderSide.none
                : (isThickRight ? thick : thin),
            bottom: row == boardSize - 1
                ? BorderSide.none
                : (isThickBottom ? thick : thin),
          ),
        ),
        alignment: Alignment.center,
        // FittedBox масштабирует цифру под размер клетки — на телефоне
        // и на большом мониторе пропорции сохранятся сами.
        child: value == 0
            ? null
            : FittedBox(
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
              ),
      ),
    );
  }
}
