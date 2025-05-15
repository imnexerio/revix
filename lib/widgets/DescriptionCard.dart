import 'package:flutter/material.dart';

class DescriptionCard extends StatefulWidget {
  final Map<String, dynamic> details;
  final Function(String) onDescriptionChanged;

  const DescriptionCard({
    Key? key,
    required this.details,
    required this.onDescriptionChanged,
  }) : super(key: key);

  @override
  _DescriptionCardState createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<DescriptionCard> {
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.details['description'] ?? 'No description available',
    );
  }

  @override
  void didUpdateWidget(DescriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update the text if it changed from outside (not from user input)
    if (oldWidget.details['description'] != widget.details['description'] &&
        _descriptionController.text != widget.details['description']) {
      _descriptionController.text = widget.details['description'] ?? 'No description available';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Description",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter description',
            ),
            onChanged: (text) {
              widget.onDescriptionChanged(text);
            },
          ),
        ],
      ),
    );
  }
}

// Usage example:
// DescriptionCard(
//   details: details,
//   onDescriptionChanged: (text) {
//     setState(() {
//       description = text;
//       details['description'] = text;
//     });
//   },
// ),