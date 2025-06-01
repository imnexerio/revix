import 'package:flutter/material.dart';
import 'SortingComponents.dart';
import 'RecordSortingUtils.dart';

/// Reusable sorting bottom sheet component
class SortingBottomSheet extends StatefulWidget {
  final String? currentSortField;
  final bool isAscending;
  final Function(String field, bool ascending) onSortApplied;

  const SortingBottomSheet({
    Key? key,
    required this.currentSortField,
    required this.isAscending,
    required this.onSortApplied,
  }) : super(key: key);

  @override
  _SortingBottomSheetState createState() => _SortingBottomSheetState();
}

class _SortingBottomSheetState extends State<SortingBottomSheet> {
  late String selectedField;
  late bool isAscending;

  @override
  void initState() {
    super.initState();
    selectedField = widget.currentSortField ?? 'reminder_time';
    isAscending = widget.isAscending;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 16),
              ),

              // Title
              Text(
                'Sort by',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Sort field selection boxes
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SortFieldBox(
                    label: 'Reminder Time',
                    field: 'reminder_time',
                    isSelected: selectedField == 'reminder_time',
                    onTap: () {
                      setState(() => selectedField = 'reminder_time');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Date Initiated',
                    field: 'date_initiated',
                    isSelected: selectedField == 'date_initiated',
                    onTap: () {
                      setState(() => selectedField = 'date_initiated');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Date Reviewed',
                    field: 'date_updated',
                    isSelected: selectedField == 'date_updated',
                    onTap: () {
                      setState(() => selectedField = 'date_updated');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Overdue Reviews',
                    field: 'missed_counts',
                    isSelected: selectedField == 'missed_counts',
                    onTap: () {
                      setState(() => selectedField = 'missed_counts');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Number of Reviews',
                    field: 'completion_counts',
                    isSelected: selectedField == 'completion_counts',
                    onTap: () {
                      setState(() => selectedField = 'completion_counts');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Review Frequency',
                    field: 'recurrence_frequency',
                    isSelected: selectedField == 'recurrence_frequency',
                    onTap: () {
                      setState(() => selectedField = 'recurrence_frequency');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Order selection
              Column(
                children: [
                  const Text('Order'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OrderBox(
                          label: 'Ascending',
                          icon: Icons.arrow_upward,
                          isSelected: isAscending,
                          onTap: () {
                            widget.onSortApplied(selectedField, true);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: OrderBox(
                          label: 'Descending',
                          icon: Icons.arrow_downward,
                          isSelected: !isAscending,
                          onTap: () {
                            widget.onSortApplied(selectedField, false);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
