import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/AddLectureForm.dart';
import 'package:retracker/DetailsPage/DetailsPage.dart';
import 'package:retracker/LoginSignupPage/LoginPage.dart';
import 'package:retracker/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AI/ChatPage.dart';
import 'HomePage/HomePage.dart';
import 'SchedulePage/TodayPage.dart';
import 'SettingsPage/SettingsPage.dart';
import 'ThemeNotifier.dart';
import 'Utils/SplashScreen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  ThemeNotifier themeNotifier = ThemeNotifier(AppThemes.themes[0], ThemeMode.system);
  // await themeNotifier.loadPreferences();
  await themeNotifier.fetchCustomTheme(); // Fetch and apply the latest custom theme

  runApp(
    ChangeNotifierProvider(
      create: (_) => themeNotifier,
      child: MyApp(isLoggedIn: isLoggedIn, prefs: prefs),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.isLoggedIn, required this.prefs}) : super(key: key);

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
            '/': (context) => SplashScreen(),
            '/home': (context) => isLoggedIn ? MyHomePage() : LoginPage(),
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  void _addLecture() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
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
    ChatPage(),
    SettingsPage()
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
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
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded, color: theme.colorScheme.primary),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.schedule_rounded),
                activeIcon: Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
                label: 'Schedule',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_rounded),
                activeIcon: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary),
                label: 'Details',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_rounded),
                activeIcon: Icon(Icons.chat_rounded, color: theme.colorScheme.primary),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded),
                activeIcon: Icon(Icons.settings, color: theme.colorScheme.primary),
                label: 'Settings',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            onTap: _onItemTapped,
          ),
        ),
        floatingActionButton: Transform.translate(
          offset: Offset(0, 10),
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
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _addLecture,
              child: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary),
              elevation: 0,
              backgroundColor: Colors.transparent,
              shape: CircleBorder(),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}