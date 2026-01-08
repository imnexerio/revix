import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


PreferredSizeWidget buildDetailPageAppBar(
    BuildContext context,
    String title,
    {VoidCallback? onBackPressed}
    ) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  
  return AppBar(
    title: Text(title),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
    ),
    centerTitle: true,
    elevation: 0,
    backgroundColor: Theme.of(context).colorScheme.surface,
    foregroundColor: Theme.of(context).colorScheme.onSurface,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: theme.colorScheme.primary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ),
  );
}