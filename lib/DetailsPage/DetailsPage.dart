import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'NavigationSidebar.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({Key? key}) : super(key: key);

  @override
  DetailsPageState createState() => DetailsPageState();
}

class DetailsPageState extends State<DetailsPage> {
  static const String _sidebarVisibilityKey = 'detailsPageSidebarVisible';
  bool _isSidebarVisible = true;
  SharedPreferences? _prefs;
  
  // Key to access sidebar state
  final GlobalKey<NavigationSidebarState> _sidebarKey = 
      GlobalKey<NavigationSidebarState>();
  
  // Sorting state for AppBar display
  String _currentSortField = 'reminder_time';
  bool _isAscending = true;

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

  // Expose sorting info for AppBar
  String get sortField => _currentSortField;
  bool get sortAscending => _isAscending;
  
  // Method to show sorting bottom sheet (called from AppBar)
  void showSortingSheet(BuildContext context) {
    _sidebarKey.currentState?.showSortingSheet(context);
  }

  void _onSortingChanged(String sortField, bool isAscending) {
    setState(() {
      _currentSortField = sortField;
      _isAscending = isAscending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NavigationSidebar(
        key: _sidebarKey,
        isSidebarVisible: _isSidebarVisible,
        onSortingChanged: _onSortingChanged,
      ),
    );
  }
}