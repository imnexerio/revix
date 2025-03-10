import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/ThemeNotifier.dart';
import '../theme_data.dart';
import 'CustomColorBuilder.dart';

class ThemePage extends StatefulWidget {
  @override
  _ThemePageState createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  late int _redValue;
  late int _greenValue;
  late int _blueValue;

  @override
  void initState() {
    super.initState();
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    themeNotifier.fetchCustomTheme();
    _redValue = themeNotifier.customThemeColor?.red ?? 0;
    _greenValue = themeNotifier.customThemeColor?.green ?? 0;
    _blueValue = themeNotifier.customThemeColor?.blue ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Predefined Themes Section
            Text(
              'Theme Selection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: themeNotifier.selectedThemeIndex,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  items: [
                    ...List.generate(AppThemes.themeNames.length, (index) {
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              margin: EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: AppThemes.themes[index * 2].colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                            ),
                            Text(
                              AppThemes.themeNames[index],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // Custom theme option
                    DropdownMenuItem<int>(
                      value: ThemeNotifier.customThemeIndex,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            margin: EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: themeNotifier.customThemeColor ?? Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                          ),
                          Text(
                            'Custom',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (int? newIndex) {
                    if (newIndex != null) {
                      if (newIndex == ThemeNotifier.customThemeIndex) {
                        // If custom theme is selected but no color is set, initialize with a default
                        if (themeNotifier.customThemeColor == null) {
                          final defaultCustomColor = Color.fromRGBO(100, 100, 100, 1);
                          themeNotifier.setCustomTheme(defaultCustomColor);
                          setState(() {
                            _redValue = defaultCustomColor.red;
                            _greenValue = defaultCustomColor.green;
                            _blueValue = defaultCustomColor.blue;
                          });
                        }
                      }
                      themeNotifier.updateThemeBasedOnMode(newIndex);
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 32),

            // Custom Theme Section - Only show when Custom is selected
            if (themeNotifier.selectedThemeIndex == ThemeNotifier.customThemeIndex)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Theme',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Color Preview
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 0.3),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // RGB Sliders
                  buildColorSlider(
                    context,
                    'Red',
                    _redValue,
                    Colors.red,
                    (value) => setState(() => _redValue = value.round()),
                  ),
                  SizedBox(height: 16),
                  buildColorSlider(
                    context,
                    'Green',
                    _greenValue,
                    Colors.green,
                    (value) => setState(() => _greenValue = value.round()),
                  ),
                  SizedBox(height: 16),
                  buildColorSlider(
                    context,
                    'Blue',
                    _blueValue,
                    Colors.blue,
                    (value) => setState(() => _blueValue = value.round()),
                  ),
                  SizedBox(height: 24),
                  // Apply Custom Theme Button
                  FilledButton(
                    onPressed: () {
                      final customColor = Color.fromRGBO(_redValue, _greenValue, _blueValue, 1);
                      themeNotifier.setCustomTheme(customColor);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Apply Custom Theme',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: 32),
            // Theme Mode Selection
            Text(
              'Theme Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ThemeMode>(
                  value: themeNotifier.currentThemeMode,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Row(
                        children: [
                          Icon(Icons.settings_suggest_outlined, size: 24),
                          SizedBox(width: 12),
                          Text('System Default'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Row(
                        children: [
                          Icon(Icons.light_mode_outlined, size: 24),
                          SizedBox(width: 12),
                          Text('Light'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Row(
                        children: [
                          Icon(Icons.dark_mode_outlined, size: 24),
                          SizedBox(width: 12),
                          Text('Dark'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (ThemeMode? newMode) {
                    if (newMode != null) {
                      themeNotifier.changeThemeMode(newMode);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}