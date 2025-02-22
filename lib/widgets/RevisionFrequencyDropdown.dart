import 'package:flutter/material.dart';
import '../Utils/fetchFrequencies_utils.dart';

class RevisionFrequencyDropdown extends StatefulWidget {
  final String revisionFrequency;
  final ValueChanged<String?> onChanged;

  const RevisionFrequencyDropdown({
    required this.revisionFrequency,
    required this.onChanged,
  });

  @override
  _RevisionFrequencyDropdownState createState() => _RevisionFrequencyDropdownState();
}

class _RevisionFrequencyDropdownState extends State<RevisionFrequencyDropdown> {
  List<DropdownMenuItem<String>> _dropdownItems = [];

  @override
  void initState() {
    super.initState();
    _fetchFrequencies();
  }

  Future<void> _fetchFrequencies() async {
    Map<String, dynamic> frequencies = await FetchFrequenciesUtils.fetchFrequencies();
    List<DropdownMenuItem<String>> items = frequencies.keys.map((key) {
      return DropdownMenuItem<String>(
        value: key,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              key,
              style: TextStyle(fontWeight: FontWeight.bold,color: Theme.of(context).colorScheme.primary),
            ),
            SizedBox(width: 10),
            Text(
              frequencies[key].toString(),
              style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      );
    }).toList();

    setState(() {
      _dropdownItems = items;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Revision Frequency',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: widget.revisionFrequency,
        onChanged: widget.onChanged,
        items: _dropdownItems,
        validator: (value) => value == null ? 'Please select a revision frequency' : null,
      ),
    );
  }
}