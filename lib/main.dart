import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/AddLectureForm.dart';
import 'package:retracker/DetailsPage/DetailsPage.dart';
import 'package:retracker/LoginSignupPage/LoginPage.dart';
import 'package:retracker/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'AI/ChatPage.dart';
import 'CustomThemeGenerator.dart';
import 'HomePage/HomePage.dart';
import 'SchedulePage/TodayPage.dart';
import 'SettingsPage/ProfileProvider.dart';
import 'SettingsPage/SettingsPage.dart';
import 'ThemeNotifier.dart';
import 'Utils/SplashScreen.dart';
import 'Utils/platform_utils.dart';
import 'Utils/GuestAuthService.dart';
import 'Utils/LocalDatabaseService.dart';
import 'Utils/HiveService.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformUtils.init();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  await HiveService.initialize();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  // Check if user is in guest mode and ensure consistency
  await HiveService.syncGuestModeStatus();
  bool isGuestMode = await GuestAuthService.isGuestMode();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
  // If user is in guest mode, initialize local database
  if (isGuestMode) {
    await LocalDatabaseService.initialize();
    // Make sure isLoggedIn is set to true for guest mode
    if (!isLoggedIn) {
      await prefs.setBool('isLoggedIn', true);
      isLoggedIn = true;
    }
  }

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

  // Set the cached values directly (they'll be applied in the constructor)
  themeNotifier.setInitialValues(cachedThemeIndex, cachedCustomColor);
  
  // If in guest mode, ensure we're using local theme settings only
  if (isGuestMode) {
    await themeNotifier.loadLocalTheme();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeNotifier),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MyApp(isLoggedIn: isLoggedIn, prefs: prefs),
    ),
  );
}


class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.isLoggedIn, required this.prefs}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'reTracker',
          theme: themeNotifier.currentTheme,
          darkTheme: themeNotifier.currentTheme,
          themeMode: themeNotifier.currentThemeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/home': (context) => widget.isLoggedIn ? const MyHomePage() : LoginPage(),
          },
        );
      },
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