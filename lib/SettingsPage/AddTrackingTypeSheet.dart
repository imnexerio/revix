import 'package:flutter/material.dart';
import 'package:revix/Utils/customSnackBar.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/lecture_colors.dart';

// lib/SettingsPage/AddTrackingTypeSheet.dart
void showAddtrackingTypeSheet(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController titleController,
    StateSetter setState,
    VoidCallback onTypeAdded, // Add this callback
    ) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return AddTrackingTypeWidget(
        formKey: formKey,
        titleController: titleController,
        onTypeAdded: onTypeAdded,
      );
    },
  );
}

class AddTrackingTypeWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final VoidCallback onTypeAdded;

  const AddTrackingTypeWidget({
    Key? key,
    required this.formKey,
    required this.titleController,
    required this.onTypeAdded,
  }) : super(key: key);

  @override
  State<AddTrackingTypeWidget> createState() => _AddTrackingTypeWidgetState();
}

class _AddTrackingTypeWidgetState extends State<AddTrackingTypeWidget> {
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _currentText = widget.titleController.text;
    widget.titleController.addListener(() {
      setState(() {
        _currentText = widget.titleController.text;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.53,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Custom Type',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: widget.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Color preview section
                      if (_currentText.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Color Preview : ',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: LectureColors.generateColorFromString(_currentText.trim()),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: widget.titleController,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          hintText: 'Enter new tracking type',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a tracking type';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // Submit button
            Container(
              padding: const EdgeInsets.all(24),
              child: FilledButton.icon(
                onPressed: () async {
                  if (widget.formKey.currentState!.validate()) {
                    try {
                      String trackingTitle = widget.titleController.text.trim();
                      // Use centralized database service
                      final firebaseService = FirebaseDatabaseService();
                      await firebaseService.addCustomTrackingType(trackingTitle);

                      widget.titleController.clear();
                      Navigator.pop(context);

                      customSnackBar(
                        context: context,
                        message: 'New tracking type added successfully',
                      );

                      widget.onTypeAdded(); // Call the callback to refresh the dropdown
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.error, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Failed to add Type'),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Type'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}