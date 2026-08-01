/// Панель ввода: ряд инструментов (undo, стереть, заметки, подсказка)
/// и кнопки цифр 1–9.
library;

import 'package:flutter/material.dart';

import 'game_controller.dart';

class InputPanel extends StatelessWidget {
  final GameController controller;

  const InputPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Инструменты ---
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _toolKey(
              icon: Icons.undo,
              tooltip: 'Отменить ход',
              onTap: controller.canUndo ? controller.undo : null,
            ),
            _toolKey(
              icon: Icons.backspace_outlined,
              tooltip: 'Стереть',
              onTap: controller.erase,
            ),
            _toolKey(
              icon: Icons.edit_outlined,
              tooltip: 'Заметки',
              onTap: controller.toggleNotesMode,
              // Активный режим заметок выделяем заливкой кнопки.
              active: controller.notesMode,
            ),
            _toolKey(
              icon: Icons.lightbulb_outline,
              tooltip: 'Подсказка (осталось: ${controller.hintsLeft})',
              onTap: controller.hintsLeft > 0 ? controller.useHint : null,
              badge: '${controller.hintsLeft}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        // --- Цифры ---
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int digit = 1; digit <= 9; digit++)
              SizedBox(
                width: 52,
                height: 52,
                child: FilledButton.tonal(
                  onPressed: () => controller.input(digit),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('$digit', style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _toolKey({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool active = false,
    String? badge,
  }) {
    final button = SizedBox(
      width: 52,
      height: 52,
      child: active
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              child: Icon(icon),
            )
          : FilledButton.tonal(
              onPressed: onTap, // null = кнопка сама станет неактивной
              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
              child: Icon(icon),
            ),
    );

    // Badge рисует маленький кружок с числом поверх кнопки — им
    // показываем остаток подсказок.
    final child =
        badge == null ? button : Badge(label: Text(badge), child: button);

    return Tooltip(message: tooltip, child: child);
  }
}
