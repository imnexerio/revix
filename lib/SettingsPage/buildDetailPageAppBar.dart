import 'package:flutter/material.dart';


PreferredSizeWidget buildDetailPageAppBar(
    BuildContext context,
    String title,
    {VoidCallback? onBackPressed}
    ) {
  return AppBar(
    title: Text(title),
    leading: IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
    ),
    centerTitle: true,
    elevation: 0,
    backgroundColor: Theme.of(context).colorScheme.surface,
    foregroundColor: Theme.of(context).colorScheme.onSurface,
  );
}