import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/ThemeNotifier.dart';
import '../theme_data.dart';

class ThemePage extends StatefulWidget {
  @override
  _ThemePageState createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> with SingleTickerProviderStateMixin {
  late int _redValue;
  late int _greenValue;
  late int _blueValue;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Debounce timer for color changes
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    Future.microtask(() => themeNotifier.fetchCustomTheme());

    _redValue = themeNotifier.customThemeColor?.red ?? 0;
    _greenValue = themeNotifier.customThemeColor?.green ?? 0;
    _blueValue = themeNotifier.customThemeColor?.blue ?? 0;

    // Use a shorter animation duration to improve perceived performance
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced from 600ms
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Optimize theme change to avoid UI freezing
  void _updateTheme(ThemeNotifier themeNotifier, int themeIndex) {

    Future.microtask(() {
      themeNotifier.updateThemeBasedOnMode(themeIndex);
    });
  }

  // Improved debounced color change with longer delay to reduce updates
  void _debouncedColorChange(ThemeNotifier themeNotifier) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final customColor = Color.fromRGBO(_redValue, _greenValue, _blueValue, 1);
      themeNotifier.setCustomTheme(customColor);
    });
  }

  // Calculate optimal grid columns based on screen width
  int _getGridColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 800) return 4;
    if (width > 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final gridColumnCount = _getGridColumnCount(context);

    return Scaffold(
      body: FadeTransition(
        opacity: _animation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme Mode Selection with visual representation
                const SectionTitle(
                  title: 'Theme Mode',
                  icon: Icons.brightness_4_rounded,
                ),
                const SizedBox(height: 16),
                _buildThemeModeSelector(context, themeNotifier),
                const SizedBox(height: 32),

                // Theme Selection Section
                const SectionTitle(
                  title: 'Color Theme',
                  icon: Icons.palette_rounded,
                ),
                const SizedBox(height: 16),
                _buildThemeGrid(themeNotifier, gridColumnCount),

                // Custom Theme Section - Only show when Custom is selected
                if (themeNotifier.selectedThemeIndex == ThemeNotifier.customThemeIndex)
                  _buildCustomThemeSection(context, themeNotifier),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeSelector(BuildContext context, ThemeNotifier themeNotifier) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Row(
          children: [
            _buildThemeModeOption(
              context: context,
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              label: 'Light',
              isSelected: themeNotifier.currentThemeMode == ThemeMode.light,
              onTap: () => themeNotifier.changeThemeMode(ThemeMode.light),
            ),
            _buildThemeModeOption(
              context: context,
              mode: ThemeMode.system,
              icon: Icons.settings_suggest_rounded,
              label: 'System',
              isSelected: themeNotifier.currentThemeMode == ThemeMode.system,
              onTap: () => themeNotifier.changeThemeMode(ThemeMode.system),
            ),
            _buildThemeModeOption(
              context: context,
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              label: 'Dark',
              isSelected: themeNotifier.currentThemeMode == ThemeMode.dark,
              onTap: () => themeNotifier.changeThemeMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeOption({
    required BuildContext context,
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), // Reduced from 300ms
          curve: Curves.easeOutQuint,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeGrid(ThemeNotifier themeNotifier, int columnCount) {
    // Calculate appropriate child aspect ratio based on column count
    double aspectRatio = columnCount > 2 ? 1.5 : 1.2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: AppThemes.themeNames.length + 1, // Add 1 for custom theme
      itemBuilder: (context, index) {
        bool isCustom = index == AppThemes.themeNames.length;
        int themeIndex = isCustom ? ThemeNotifier.customThemeIndex : index;
        String themeName = isCustom ? 'Custom' : AppThemes.themeNames[index];
        Color themeColor = isCustom
            ? themeNotifier.customThemeColor ?? Colors.grey
            : AppThemes.themes[index * 2].colorScheme.primary;
        bool isSelected = themeNotifier.selectedThemeIndex == themeIndex;

        return GestureDetector(
          onTap: () {
            _updateTheme(themeNotifier, themeIndex);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), // Reduced from 300ms
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? themeColor
                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? themeColor.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Use RepaintBoundary to optimize repainting
                RepaintBoundary(
                  child: Hero(
                    tag: 'theme_color_$themeIndex',
                    child: Container(
                      width: 42, // Slightly smaller
                      height: 42, // Slightly smaller
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withOpacity(0.4),
                            blurRadius: 8, // Smaller blur radius
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                        Icons.check,
                        color: themeColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        size: 24, // Smaller icon
                      )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8), // Smaller spacing
                Text(
                  themeName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14, // Smaller font
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomThemeSection(BuildContext context, ThemeNotifier themeNotifier) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useCompactLayout = screenWidth > 600;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const SectionTitle(
            title: 'Custom Color',
            icon: Icons.color_lens_rounded,
          ),
          const SizedBox(height: 20),

          // For wider screens, place preview and sliders side by side
          if (useCompactLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color Preview
                Expanded(
                  flex: 2,
                  child: _buildColorPreview(),
                ),
                const SizedBox(width: 24),
                // RGB Sliders
                Expanded(
                  flex: 3,
                  child: _buildSliders(context, themeNotifier),
                ),
              ],
            )
          else
            Column(
              children: [
                // Color Preview
                _buildColorPreview(),
                const SizedBox(height: 30),
                // RGB Sliders
                _buildSliders(context, themeNotifier),
              ],
            ),

          const SizedBox(height: 30),

          // Apply Custom Theme Button
          ElevatedButton(
            onPressed: () {
              final customColor = Color.fromRGBO(_redValue, _greenValue, _blueValue, 1);

              Future.microtask(() {
                themeNotifier.setCustomTheme(customColor);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Custom theme applied!'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    duration: const Duration(seconds: 2),
                    margin: const EdgeInsets.all(16),
                    elevation: 6,
                  ),
                );
              });
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
              shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 24),
                SizedBox(width: 12),
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
        ],
      ),
    );
  }

  Widget _buildColorPreview() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100, // Smaller size
        height: 100, // Smaller size
        decoration: BoxDecoration(
          color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 0.4),
              blurRadius: 15, // Reduced blur
              spreadRadius: 3,  // Reduced spread
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RGB',
                style: TextStyle(
                  color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1).computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Smaller font
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_redValue, $_greenValue, $_blueValue',
                style: TextStyle(
                  color: Color.fromRGBO(_redValue, _greenValue, _blueValue, 1).computeLuminance() > 0.5
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.7),
                  fontSize: 10, // Smaller font
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliders(BuildContext context, ThemeNotifier themeNotifier) {
    return Column(
      children: [
        _buildColorSlider(
          context,
          'Red',
          _redValue,
          Colors.red,
              (value) {
            setState(() => _redValue = value.round());
            _debouncedColorChange(themeNotifier);
          },
        ),
        const SizedBox(height: 16),
        _buildColorSlider(
          context,
          'Green',
          _greenValue,
          Colors.green,
              (value) {
            setState(() => _greenValue = value.round());
            _debouncedColorChange(themeNotifier);
          },
        ),
        const SizedBox(height: 16),
        _buildColorSlider(
          context,
          'Blue',
          _blueValue,
          Colors.blue,
              (value) {
            setState(() => _blueValue = value.round());
            _debouncedColorChange(themeNotifier);
          },
        ),
      ],
    );
  }

  Widget _buildColorSlider(
      BuildContext context,
      String label,
      int value,
      Color color,
      Function(double) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Container(
              width: 50,
              height: 26,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Wrap sliders in RepaintBoundary for performance
        RepaintBoundary(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9), // Smaller thumb
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20), // Smaller overlay
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.3),
            ),
            child: Slider(
              min: 0,
              max: 255,
              value: value.toDouble(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20, // Smaller icon
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18, // Smaller text
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}