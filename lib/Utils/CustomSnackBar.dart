import 'package:flutter/material.dart';

SnackBar customSnackBar({
  required BuildContext context,
  required String message,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 2),
  SnackBarBehavior behavior = SnackBarBehavior.floating,
  ShapeBorder? shape,
}) {
  return SnackBar(
    content: Row(
      children: [
        Icon(Icons.check_circle, color: Colors.white),
        SizedBox(width: 8),
        Flexible(
          child: Text(message),
        ),
      ],
    ),
    backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
    duration: duration,
    behavior: behavior,
    shape: shape ?? RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  );
}