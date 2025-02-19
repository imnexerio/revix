import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data/custom_frequencies');
      DataSnapshot snapshot = await databaseRef.get();
      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _dropdownItems = data.keys.map((key) {
            return DropdownMenuItem<String>(
              value: key,
              child: Text(key),
            );
          }).toList();
        });
      }
    } catch (e) {
      // Handle error
    }
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