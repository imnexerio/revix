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
      body: CategoriesBar(
        isSidebarVisible: _isSidebarVisible,
      ),
    );
  }
}