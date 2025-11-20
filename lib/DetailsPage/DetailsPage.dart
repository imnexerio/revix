import 'package:flutter/material.dart';

import 'CategoriesBar.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({Key? key}) : super(key: key);

  @override
  DetailsPageState createState() => DetailsPageState();
}

class DetailsPageState extends State<DetailsPage> {
  bool _isSidebarVisible = true;

  @override
  void initState() {
    super.initState();
  }

  void toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 88.0),
        child: CategoriesBar(
          isSidebarVisible: _isSidebarVisible,
        ),
      ),
    );
  }
}