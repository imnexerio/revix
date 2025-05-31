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
                    field: 'date_learnt',
                    isSelected: selectedField == 'date_learnt',
                    onTap: () {
                      setState(() => selectedField = 'date_learnt');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Date Reviewed',
                    field: 'date_revised',
                    isSelected: selectedField == 'date_revised',
                    onTap: () {
                      setState(() => selectedField = 'date_revised');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Overdue Reviews',
                    field: 'missed_revision',
                    isSelected: selectedField == 'missed_revision',
                    onTap: () {
                      setState(() => selectedField = 'missed_revision');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Number of Reviews',
                    field: 'no_revision',
                    isSelected: selectedField == 'no_revision',
                    onTap: () {
                      setState(() => selectedField = 'no_revision');
                      widget.onSortApplied(selectedField, isAscending);
                      Navigator.pop(context);
                    },
                  ),
                  SortFieldBox(
                    label: 'Review Frequency',
                    field: 'revision_frequency',
                    isSelected: selectedField == 'revision_frequency',
                    onTap: () {
                      setState(() => selectedField = 'revision_frequency');
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
