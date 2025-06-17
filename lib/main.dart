import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:revix/AddLectureForm.dart';
import 'package:revix/DetailsPage/DetailsPage.dart';
import 'package:revix/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'AI/ChatPage.dart';
import 'CustomThemeGenerator.dart';
import 'HomePage/HomePage.dart';
import 'HomeWidget/HomeWidgetManager.dart';
import 'SchedulePage/TodayPage.dart';
import 'SettingsPage/ProfileProvider.dart';
import 'SettingsPage/SettingsPage.dart';
import 'ThemeNotifier.dart';
import 'Utils/SplashScreen.dart';
import 'Utils/platform_utils.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformUtils.init();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();

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

  @override
  void initState() {
    super.initState();
    Provider.of<ProfileProvider>(context, listen: false).loadProfileImage(context);
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

  final List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    TodayPage(),
    DetailsPage(),
    const ChatPage(),
  ];

  final List<String> _pageTitles = <String>[
    'Home',
    'Schedule',
    'Details',
    'Chat',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _pageTitles[_selectedIndex],
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
          actions: [
            InkWell(
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
            )
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: _widgetOptions,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded, color: theme.colorScheme.primary),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.today_outlined),
                activeIcon: Icon(Icons.today_rounded, color: theme.colorScheme.primary),
                label: 'Schedule',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.fiber_smart_record_outlined),
                activeIcon: Icon(Icons.fiber_smart_record_rounded, color: theme.colorScheme.primary),
                label: 'Details',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                label: 'Chat',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            onTap: _onItemTapped,
          ),
        ),
        floatingActionButton: Transform.translate(
          offset: const Offset(0, 10),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _addLecture,
              child: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary),
              elevation: 0,
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}