import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_button.dart';

void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: AppColors.present,
      behavior: SnackBarBehavior.floating,
      width: 480,
    ));
}

void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: AppColors.absent,
      behavior: SnackBarBehavior.floating,
      width: 480,
      duration: const Duration(seconds: 5),
    ));
}

/// Confirm dialog; resolves to true when confirmed. Optional [icon] and a
/// [destructive] flag that switches the confirm button to the danger variant.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon,
              color: destructive
                  ? AppColors.absent
                  : Theme.of(ctx).colorScheme.primary),
      title: Text(title),
      content: SizedBox(width: 420, child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        destructive
            ? AppButton.danger(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              )
            : AppButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
      ],
    ),
  );
  return result ?? false;
}
