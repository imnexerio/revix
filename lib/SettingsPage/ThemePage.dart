import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/ThemeNotifier.dart';

import '../theme_data.dart';
import 'CustomColorBuilder.dart';

void showThemeBottomSheet(BuildContext context) {
  final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

  // Fetch the custom theme color from Firebase
  themeNotifier.fetchCustomTheme();

  // RGB values for custom theme
  int _redValue = themeNotifier.customThemeColor?.red ?? 0;
  int _greenValue = themeNotifier.customThemeColor?.green ?? 0;
  int _blueValue = themeNotifier.customThemeColor?.blue ?? 0;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Appearance',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Customize your app theme',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ],
                        ),
                        SizedBox(height: 32),
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
                        Consumer<ThemeNotifier>(
                          builder: (context, themeNotifier, child) {
                            return Container(
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
                            );
                          },
                        ),
                        SizedBox(height: 32),

                        // Custom Theme Section - Only show when Custom is selected
                        Consumer<ThemeNotifier>(
                          builder: (context, themeNotifier, child) {
                            if (themeNotifier.selectedThemeIndex != ThemeNotifier.customThemeIndex) {
                              return SizedBox.shrink();
                            }
                            return Column(
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
                                    Navigator.pop(context);
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
                            );
                          },
                        ),

                        SizedBox(height: 32),
                        // Theme Mode Selection (remains the same)
                        Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 12),
                        Consumer<ThemeNotifier>(
                          builder: (context, themeNotifier, child) {
                            return Container(
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}