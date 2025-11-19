import 'package:flutter/material.dart';

import 'CategoriesBar.dart';

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
      padding: const EdgeInsets.only(bottom: 88.0), // Extra space for bottom navigation
      child: Center(
        child: CategoriesBar(),
      ),
    ),
  );
}}