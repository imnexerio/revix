import 'package:flutter/material.dart';

class CustomizationBottomSheet extends StatefulWidget {
  final String type;
  final String typeTitle;
  final List<String> trackingTypes;
  final Set<String> initialSelected;
  final TextEditingController controller;

  const CustomizationBottomSheet({
    Key? key,
    required this.type,
    required this.typeTitle,
    required this.trackingTypes,
    required this.initialSelected,
    required this.controller,
  }) : super(key: key);

  @override
  _CustomizationBottomSheetState createState() => _CustomizationBottomSheetState();
}

class _CustomizationBottomSheetState extends State<CustomizationBottomSheet> {
  late Set<String> selectedTypes;

  @override
  void initState() {
    super.initState();
    // Create a new set with the initial values to avoid modifying the original
    selectedTypes = Set.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customize ${widget.typeTitle}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Add a save button to close and return the selected values
              TextButton(
                onPressed: () {
                  Navigator.pop(context, selectedTypes.toList());
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Show tracking types
          if (widget.trackingTypes.isNotEmpty) ...[
            const Text(
              'Select Tracking Type:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.trackingTypes.length,
                itemBuilder: (context, index) {
                  final type = widget.trackingTypes[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type),
                      selected: selectedTypes.contains(type),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTypes.add(type);
                          } else {
                            selectedTypes.remove(type);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}