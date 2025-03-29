import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/ThemeNotifier.dart';
import '../theme_data.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Appearance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Mode Selection
              _buildSectionHeader(context, 'Display Mode', Icons.brightness_6_rounded),
              const SizedBox(height: 16),
              _buildThemeModeSelector(themeNotifier, colorScheme),
              const SizedBox(height: 32),

              // Predefined Themes Section
              _buildSectionHeader(context, 'Color Theme', Icons.palette_outlined),
              const SizedBox(height: 16),
              _buildThemeSelector(themeNotifier, colorScheme),
              const SizedBox(height: 32),

              // Custom Theme Section - Only show when Custom is selected
              if (themeNotifier.selectedThemeIndex == ThemeNotifier.customThemeIndex)
                _buildCustomThemeSection(context, themeNotifier, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeSelector(ThemeNotifier themeNotifier, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildThemeModeOption(
            themeNotifier,
            ThemeMode.system,
            'System',
            Icons.settings_suggest_outlined,
            colorScheme,
          ),
          _buildThemeModeOption(
            themeNotifier,
            ThemeMode.light,
            'Light',
            Icons.light_mode_outlined,
            colorScheme,
          ),
          _buildThemeModeOption(
            themeNotifier,
            ThemeMode.dark,
            'Dark',
            Icons.dark_mode_outlined,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
      ThemeNotifier themeNotifier,
      ThemeMode themeMode,
      String label,
      IconData icon,
      ColorScheme colorScheme,
      ) {
    final isSelected = themeNotifier.currentThemeMode == themeMode;

    return Expanded(
      child: GestureDetector(
        onTap: () => themeNotifier.changeThemeMode(themeMode),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeNotifier themeNotifier, ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: AppThemes.themeNames.length + 1, // +1 for custom theme
      itemBuilder: (context, index) {
        bool isCustom = index == AppThemes.themeNames.length;
        bool isSelected = isCustom
            ? themeNotifier.selectedThemeIndex == ThemeNotifier.customThemeIndex
            : themeNotifier.selectedThemeIndex == index;

        Color themeColor = isCustom
            ? themeNotifier.customThemeColor ?? Colors.grey
            : AppThemes.themes[index * 2].colorScheme.primary;

        String themeName = isCustom ? 'Custom' : AppThemes.themeNames[index];

        return GestureDetector(
          onTap: () {
            if (isCustom) {
              if (themeNotifier.customThemeColor == null) {
                final defaultCustomColor = Color.fromRGBO(100, 100, 100, 1);
                themeNotifier.setCustomTheme(defaultCustomColor);
                setState(() {
                  _redValue = defaultCustomColor.red;
                  _greenValue = defaultCustomColor.green;
                  _blueValue = defaultCustomColor.blue;
                });
              }
              themeNotifier.updateThemeBasedOnMode(ThemeNotifier.customThemeIndex);
            } else {
              themeNotifier.updateThemeBasedOnMode(index);
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: themeColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  themeName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomThemeSection(
      BuildContext context,
      ThemeNotifier themeNotifier,
      ColorScheme colorScheme,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Customize Theme', Icons.color_lens_outlined),
        const SizedBox(height: 24),

        // Color Preview
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.color_lens,
                  size: 18,
                  color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Color values display
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'RGB: $_redValue, $_greenValue, $_blueValue',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // RGB Sliders
        _buildColorSlider(
          context: context,
          label: 'Red',
          value: _redValue,
          color: Colors.red,
          onChanged: (value) => setState(() => _redValue = value.round()),
        ),
        const SizedBox(height: 16),
        _buildColorSlider(
          context: context,
          label: 'Green',
          value: _greenValue,
          color: Colors.green,
          onChanged: (value) => setState(() => _greenValue = value.round()),
        ),
        const SizedBox(height: 16),
        _buildColorSlider(
          context: context,
          label: 'Blue',
          value: _blueValue,
          color: Colors.blue,
          onChanged: (value) => setState(() => _blueValue = value.round()),
        ),
        const SizedBox(height: 32),

        // Apply Custom Theme Button
        ElevatedButton(
          onPressed: () {
            final customColor = Color.fromRGBO(_redValue, _greenValue, _blueValue, 1);
            themeNotifier.setCustomTheme(customColor);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.brush_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Apply Custom Theme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildColorSlider({
    required BuildContext context,
    required String label,
    required int value,
    required Color color,
    required Function(double) onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onBackground,
              ),
            ),
            Container(
              width: 44,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}