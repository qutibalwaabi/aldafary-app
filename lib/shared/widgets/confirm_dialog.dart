import 'package:flutter/material.dart';
import 'package:untitled/shared/theme/app_theme.dart';
import 'package:untitled/theme/app_colors.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'تأكيد',
  String cancelText = 'إلغاء',
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: AppTheme.heading3,
      ),
      content: Text(
        message,
        style: AppTheme.bodyLarge,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelText,
            style: const TextStyle(color: AppColors.textOnLight),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: isDanger ? AppTheme.dangerButtonStyle : AppTheme.primaryButtonStyle,
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return result ?? false;
}

