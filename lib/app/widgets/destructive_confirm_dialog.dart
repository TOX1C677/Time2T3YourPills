import 'package:flutter/material.dart';

/// Один стиль с [medications_screen] (Dismissible): крупный текст, две равные [FilledButton].
Future<bool> showDestructiveConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String cancelLabel = 'Отмена',
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final dialogTheme = Theme.of(ctx).textTheme;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        title: Text(
          title,
          style: dialogTheme.titleLarge?.copyWith(
            fontSize: 31,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          body,
          style: dialogTheme.bodyLarge?.copyWith(
            fontSize: 26,
            height: 1.62,
          ),
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 17),
                        minimumSize: const Size(0, 84),
                        textStyle: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 17),
                        minimumSize: const Size(0, 84),
                        textStyle: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
