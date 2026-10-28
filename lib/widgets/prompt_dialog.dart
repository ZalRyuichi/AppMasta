import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'sync_widgets.dart';

Future<String?> showPromptDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  int maxLines = 1,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ElegantCard.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.neoBlack, width: 3),
      ),
      title: Text(title, style: AppTypography.menuTitle()),
      content: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Batal', style: TextStyle(color: AppColors.dashTextMuted, fontWeight: FontWeight.w600)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.dashAccent, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Kirim'),
        ),
      ],
    ),
  );
}