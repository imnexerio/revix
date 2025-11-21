import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:revix/AddLectureForm.dart';
import 'package:revix/DetailsPage/DetailsPage.dart';
import 'package:revix/Utils/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'AI/ChatPage.dart';
import 'Utils/CustomThemeGenerator.dart';
import 'HomePage/HomePage.dart';
import 'HomeWidget/HomeWidgetManager.dart';
import 'SchedulePage/TodayPage.dart';
import 'SettingsPage/ProfileProvider.dart';
import 'SettingsPage/SettingsPage.dart';
import 'Utils/ThemeNotifier.dart';
import 'Utils/SplashScreen.dart';
import 'Utils/lecture_colors.dart';
import 'Utils/platform_utils.dart';
import 'Utils/VersionChecker.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformUtils.init();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await LectureColors.initializeColors();
  // Initialize HomeWidget service for background callbacks
  if (PlatformUtils.instance.isAndroid) {
    await HomeWidgetService.initialize();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  ThemeNotifier? _themeNotifier;
  ProfileProvider? _profileProvider;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
            
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      // Load cached theme data from SharedPreferences
      ThemeMode cachedThemeMode = ThemeMode.system;
      int cachedThemeIndex = 0;
      Color? cachedCustomColor;

      // Load saved theme mode
      final themeModeString = prefs.getString(ThemeNotifier.prefThemeMode);
      if (themeModeString != null) {
        cachedThemeMode = ThemeMode.values.firstWhere(
                (e) => e.toString() == themeModeString,
            orElse: () => ThemeMode.system
        );
      }

      // Load saved theme index
      cachedThemeIndex = prefs.getInt(ThemeNotifier.prefThemeIndex) ?? 0;

      // Load custom theme color if exists
      final customColorValue = prefs.getInt(ThemeNotifier.prefCustomThemeColor);
      if (customColorValue != null) {
        cachedCustomColor = Color(customColorValue);
      }

      // Initialize the correct theme based on cached data
      ThemeData initialTheme;
      if (cachedThemeIndex == ThemeNotifier.customThemeIndex && cachedCustomColor != null) {
        // Apply custom theme
        if (cachedThemeMode == ThemeMode.system) {
          final brightness = WidgetsBinding.instance.window.platformBrightness;
          initialTheme = brightness == Brightness.dark
              ? CustomThemeGenerator.generateDarkTheme(cachedCustomColor)
              : CustomThemeGenerator.generateLightTheme(cachedCustomColor);
        } else {
          initialTheme = cachedThemeMode == ThemeMode.dark
              ? CustomThemeGenerator.generateDarkTheme(cachedCustomColor)
              : CustomThemeGenerator.generateLightTheme(cachedCustomColor);
        }
      } else {
        // Apply predefined theme
        if (cachedThemeMode == ThemeMode.system) {
          final brightness = WidgetsBinding.instance.window.platformBrightness;
          initialTheme = AppThemes.themes[cachedThemeIndex * 2 + (brightness == Brightness.dark ? 1 : 0)];
        } else {
          initialTheme = AppThemes.themes[cachedThemeIndex * 2 + (cachedThemeMode == ThemeMode.dark ? 1 : 0)];
        }
      }

      // Create ThemeNotifier with the cached theme data
      ThemeNotifier themeNotifier = ThemeNotifier(initialTheme, cachedThemeMode);
      themeNotifier.setInitialValues(cachedThemeIndex, cachedCustomColor);

      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _themeNotifier = themeNotifier;
          _profileProvider = ProfileProvider();
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error during app initialization: $e');
      // Set default values in case of error
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _themeNotifier = ThemeNotifier(AppThemes.themes[0], ThemeMode.system);
          _profileProvider = ProfileProvider();
          _isInitialized = true;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {    // Show splash screen with default theme while initializing
    if (!_isInitialized || _themeNotifier == null || _profileProvider == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'revix',
        theme: AppThemes.themes[0], // Default light theme
        home: SplashScreen(
          isLoggedIn: _isLoggedIn,
          isInitialized: _isInitialized,
        ),
        onUnknownRoute: (settings) {
          // Handle unknown routes by redirecting to splash screen
          return MaterialPageRoute(
            builder: (context) => SplashScreen(
              isLoggedIn: _isLoggedIn,
              isInitialized: _isInitialized,
            ),
          );
        },
      );
    }

    // Once initialized, show the app with proper providers and routing
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeNotifier!),
        ChangeNotifierProvider.value(value: _profileProvider!),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'revix',
            theme: themeNotifier.currentTheme,
            darkTheme: themeNotifier.currentTheme,
            themeMode: themeNotifier.currentThemeMode,
            home: SplashScreen(
              isLoggedIn: _isLoggedIn,
              isInitialized: _isInitialized,
            ),
            onUnknownRoute: (settings) {
              // Handle unknown routes by redirecting to splash screen
              return MaterialPageRoute(
                builder: (context) => SplashScreen(
                  isLoggedIn: _isLoggedIn,
                  isInitialized: _isInitialized,
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ChatPageState> _chatPageKey = GlobalKey<ChatPageState>();
  final GlobalKey<DetailsPageState> _detailsPageKey = GlobalKey<DetailsPageState>();
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomePage(),
      TodayPage(),
      DetailsPage(key: _detailsPageKey),
      ChatPage(key: _chatPageKey),
    ];
    Provider.of<ProfileProvider>(context, listen: false).loadProfileImage(context);
    
    // Check for app updates after a short delay to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          VersionChecker.checkForUpdates(context);
        }
      });
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage()),
    ).then((_) {
      // Reload profile picture when returning from settings
      Provider.of<ProfileProvider>(context, listen: false).loadProfileImage(context);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Build hamburger menu button for Chat tab
  Widget _buildChatMenuButton(ThemeData theme) {
    return IconButton(
      icon: Icon(
        Icons.menu,
        color: theme.colorScheme.onSurface,
      ),
      onPressed: () {
        _chatPageKey.currentState?.openDrawer();
      },
      tooltip: 'Chat History',
    );
  }

  // Build chat-specific action buttons
  List<Widget> _buildChatActions(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final chatState = _chatPageKey.currentState;
    
    return [
      // API Key button
      Material(
        borderRadius: BorderRadius.circular(20),
        color: (chatState?.isAiEnabled ?? false)
            ? colorScheme.primaryContainer.withOpacity(0.8)
            : colorScheme.errorContainer.withOpacity(0.8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _chatPageKey.currentState?.showApiKeyDialog();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  (chatState?.isAiEnabled ?? false) ? Icons.key : Icons.key_off,
                  size: 16,
                  color: (chatState?.isAiEnabled ?? false)
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  (chatState?.isAiEnabled ?? false) ? 'API Key' : 'Set Key',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (chatState?.isAiEnabled ?? false)
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Model selection button
      Material(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.secondaryContainer.withOpacity(0.8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _chatPageKey.currentState?.showModelSelectionDialog();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology,
                  size: 16,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'Model',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
    ];
  }

  // Build profile button (used on all tabs)
  Widget _buildProfileButton(ThemeData theme) {
    return InkWell(
      onTap: _openSettings,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              return profileProvider.profileImage != null
                  ? CircleAvatar(
                      radius: 17.5,
                      backgroundImage: profileProvider.profileImage!.image,
                      backgroundColor: Colors.transparent,
                    )
                  : Container(
                      width: 35,
                      height: 35,
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    );
            },
          ),
        ),
      ),
    );
  }

  void _addLecture() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: AddLectureForm(),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, ThemeData theme) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final List<String> _pageTitles = <String>[
    'Home',
    'Schedule',
    'Details',
    'Chat',
  ];

  // Build hamburger menu button for Details tab
  Widget _buildDetailsMenuButton(ThemeData theme) {
    return IconButton(
      icon: Icon(
        Icons.menu,
        color: theme.colorScheme.onSurface,
      ),
      onPressed: () {
        // Toggle the sidebar visibility in DetailsPage
        _detailsPageKey.currentState?.toggleSidebar();
      },
      tooltip: 'Toggle Categories',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: (_selectedIndex == 3 || _selectedIndex == 2) ? null : Text(
            _pageTitles[_selectedIndex],
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
          leading: _selectedIndex == 3 
              ? _buildChatMenuButton(theme) 
              : _selectedIndex == 2 
                  ? _buildDetailsMenuButton(theme)
                  : null,
          actions: [
            if (_selectedIndex == 3) ..._buildChatActions(theme),
            _buildProfileButton(theme),
          ],
        ),
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: _widgetOptions,
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Custom navigation bar with rounded corners - takes remaining space
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        // Lower opacity for more transparency (glassier effect)
                        color: theme.colorScheme.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home', theme),
                              _buildNavItem(1, Icons.today_outlined, Icons.today_rounded, 'Schedule', theme),
                              _buildNavItem(2, Icons.fiber_smart_record_outlined, Icons.fiber_smart_record_rounded, 'Details', theme),
                              _buildNavItem(3, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Chat', theme),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Add lecture button
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface.withOpacity(0.5),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _addLecture,
                        borderRadius: BorderRadius.circular(28),
                        child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          child: Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}