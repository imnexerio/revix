import 'package:flutter/material.dart';

void customSnackBar_error({
  required BuildContext context,
  required String message,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 2),
  SnackBarBehavior behavior = SnackBarBehavior.floating,
  ShapeBorder? shape,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(message),
          ),
        ],
      ),
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.error,
      duration: duration,
      behavior: behavior,
      shape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}