import 'package:flutter/material.dart';
import 'UnifiedDatabaseService.dart';
import 'CustomSnackBar.dart';
import 'customSnackBar_error.dart';

class DeleteConfirmationDialog {
  // Delete individual record
  static Future<void> showDeleteRecord({
    required BuildContext context,
    required String category,
    required String subCategory, 
    required String recordTitle,
  }) async {
    final result = await _showConfirmation(
      context: context,
      title: 'Delete Record',
      content: 'Delete "$recordTitle"?\n\nThis action cannot be undone.',
    );
    
    if (result == true) {
      await _executeDelete(
        context: context,
        operation: () => UnifiedDatabaseService().deleteRecord(category, subCategory, recordTitle),
        successMessage: 'Record "$recordTitle" deleted',
      );
    }
  }

  // Delete subcategory and all its records
  static Future<void> showDeleteSubCategory({
    required BuildContext context,
    required String category,
    required String subCategory,
  }) async {
    final result = await _showConfirmation(
      context: context,
      title: 'Delete Subcategory',
      content: 'Delete "$subCategory" and all its records?\n\nThis action cannot be undone.',
    );
    
    if (result == true) {
      await _executeDelete(
        context: context,
        operation: () => UnifiedDatabaseService().deleteSubCategory(category, subCategory),
        successMessage: 'Subcategory "$subCategory" deleted',
      );
    }
  }

  // Delete category and all its subcategories/records
  static Future<void> showDeleteCategory({
    required BuildContext context,
    required String category,
  }) async {
    final result = await _showConfirmation(
      context: context,
      title: 'Delete Category',
      content: 'Delete "$category" and all its data?\n\nThis action cannot be undone.',
    );
    
    if (result == true) {
      await _executeDelete(
        context: context,
        operation: () => UnifiedDatabaseService().deleteCategory(category),
        successMessage: 'Category "$category" deleted',
      );
    }
  }

  // Private confirmation dialog with theme-aware styling
  static Future<bool?> _showConfirmation({
    required BuildContext context,
    required String title,
    required String content,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'DELETE',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Private delete execution with proper error handling
  static Future<void> _executeDelete({
    required BuildContext context,
    required Future<bool> Function() operation,
    required String successMessage,
  }) async {
    try {
      final success = await operation();
      if (success) {
        customSnackBar(context: context, message: successMessage);
      } else {
        customSnackBar_error(context: context, message: 'Delete operation failed');
      }
    } catch (e) {
      customSnackBar_error(context: context, message: 'Delete failed: ${e.toString()}');
    }
  }
}