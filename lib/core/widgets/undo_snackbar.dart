import 'package:flutter/material.dart';

/// Shows a snackbar with a destructive action message and an UNDO button
/// for ~5 seconds. If the user taps UNDO before it dismisses, [onUndo]
/// fires and the original action is reverted by the caller.
class UndoSnackbar {
  UndoSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    // Guard against use-after-dispose from async callers.
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Prevent undo snackbars from queueing on rapid successive deletes.
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        content: Text(message, textDirection: TextDirection.rtl),
        action: SnackBarAction(label: 'ביטול', onPressed: onUndo),
      ),
    );
  }
}
