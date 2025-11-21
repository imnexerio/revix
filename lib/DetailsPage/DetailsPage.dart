import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'CategoriesBar.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({Key? key}) : super(key: key);

  @override
  DetailsPageState createState() => DetailsPageState();
}

class DetailsPageState extends State<DetailsPage> {
  static const String _sidebarVisibilityKey = 'detailsPageSidebarVisible';
  bool _isSidebarVisible = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final savedState = _prefs!.getBool(_sidebarVisibilityKey) ?? true;
    if (mounted && savedState != _isSidebarVisible) {
      setState(() {
        _isSidebarVisible = savedState;
      });
    }
  }

  void toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
    // Save state asynchronously without awaiting
    _prefs?.setBool(_sidebarVisibilityKey, _isSidebarVisible);
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