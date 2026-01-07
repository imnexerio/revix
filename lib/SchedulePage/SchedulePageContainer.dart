import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'TodayPage.dart';
import 'CalendarView/CalendarPage.dart';

enum ScheduleViewMode { list, calendar }

/// Container that toggles between List view (TodayPage) and Calendar view
/// Similar pattern to DetailsPage with sidebar toggle
class SchedulePageContainer extends StatefulWidget {
  const SchedulePageContainer({Key? key}) : super(key: key);

  @override
  SchedulePageContainerState createState() => SchedulePageContainerState();
}

class SchedulePageContainerState extends State<SchedulePageContainer> {
  static const String _viewModeKey = 'schedulePageViewMode';
  static const String _sidebarVisibilityKey = 'schedulePageSidebarVisible';
  
  ScheduleViewMode _viewMode = ScheduleViewMode.list;
  bool _isSidebarVisible = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final savedViewMode = _prefs!.getInt(_viewModeKey) ?? 0;
    final savedSidebarState = _prefs!.getBool(_sidebarVisibilityKey) ?? true;
    
    if (mounted) {
      setState(() {
        _viewMode = ScheduleViewMode.values[savedViewMode.clamp(0, 1)];
        _isSidebarVisible = savedSidebarState;
      });
    }
  }

  void toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
    _prefs?.setBool(_sidebarVisibilityKey, _isSidebarVisible);
  }

  void _setViewMode(ScheduleViewMode mode) {
    setState(() {
      _viewMode = mode;
    });
    _prefs?.setInt(_viewModeKey, mode.index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // View mode toggle sidebar (List vs Calendar)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: 40.0,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
              ),
            ),
            child: _buildViewModeSidebar(colorScheme),
          ),
          
          // Main content
          Expanded(
            child: _viewMode == ScheduleViewMode.list
                ? TodayPage()
                : CalendarPage(isSidebarVisible: _isSidebarVisible),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSidebar(ColorScheme colorScheme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // List view button
        _buildViewModeButton(
          ScheduleViewMode.list,
          Icons.view_list,
          'List View',
          colorScheme,
        ),
        const SizedBox(height: 8),
        // Calendar view button
        _buildViewModeButton(
          ScheduleViewMode.calendar,
          Icons.calendar_month,
          'Calendar View',
          colorScheme,
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildViewModeButton(
    ScheduleViewMode mode,
    IconData icon,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = _viewMode == mode;
    
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: () => _setViewMode(mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
