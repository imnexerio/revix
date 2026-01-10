import 'package:flutter/material.dart';
import 'RecordSortingUtils.dart';

/// Reusable filter button component that shows current sorting state
class FilterButton extends StatelessWidget {
  final String? currentSortField;
  final bool isAscending;
  final VoidCallback onPressed;

  const FilterButton({
    Key? key,
    required this.currentSortField,
    required this.isAscending,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentSortField != null
                    ? '(${RecordSortingUtils.getSortFieldDisplayName(currentSortField!)} ${isAscending ? '↑' : '↓'})'
                    : '(Unsorted)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.filter_list, size: 16),
          ],
        ),
      ),
    );
  }
}
