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
      String frequency = frequencies[key].toString();
      return DropdownMenuItem<String>(
        value: key,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Get the available width from LayoutBuilder
            double availableWidth = constraints.maxWidth;

            return Container(
              width: availableWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text(
                      frequency,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }).toList();

    setState(() {
      _dropdownItems = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Revision Frequency',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              value: widget.revisionFrequency,
              onChanged: widget.onChanged,
              items: _dropdownItems,
              menuMaxHeight: MediaQuery.of(context).size.height * 0.5, // Limit menu height to half the screen
              validator: (value) => value == null ? 'Please select a revision frequency' : null,
            ),
          ),
        );
      },
    );
  }
}