import 'package:flutter/material.dart';

import 'SubjectsBar.dart';

class DetailsPage extends StatefulWidget {
  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {

  @override
  void initState() {
    super.initState();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(0.0),
      child: Center(
        child: SubjectsBar(),
      ),
    ),
  );
}}