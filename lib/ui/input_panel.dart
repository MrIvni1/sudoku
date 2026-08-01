/// Панель ввода: кнопки 1–9 и стирание.
///
/// Wrap сам переносит кнопки на новую строку, если не хватает ширины —
/// простейшая адаптивность бесплатно.
library;

import 'package:flutter/material.dart';

import 'game_controller.dart';

class InputPanel extends StatelessWidget {
  final GameController controller;

  const InputPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int digit = 1; digit <= 9; digit++)
          _key(
            context,
            label: '$digit',
            onTap: () => controller.input(digit),
          ),
        _key(
          context,
          icon: Icons.backspace_outlined,
          onTap: controller.erase,
        ),
      ],
    );
  }

  Widget _key(BuildContext context,
      {String? label, IconData? icon, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      height: 52,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: label != null
            ? Text(label, style: const TextStyle(fontSize: 22))
            : Icon(icon, color: colors.onSecondaryContainer),
      ),
    );
  }
}
