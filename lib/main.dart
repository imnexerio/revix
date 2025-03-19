import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retracker/AddLectureForm.dart';
import 'package:retracker/DetailsPage/DetailsPage.dart';
import 'package:retracker/LoginSignupPage/LoginPage.dart';
import 'package:retracker/theme_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:typed_data';
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

// Helper function to get profile picture
Future<String?> getProfilePicture(String uid) async {
  try {
    DatabaseReference databaseRef = FirebaseDatabase.instance.ref('users/$uid/profile_data');
    DataSnapshot snapshot = await databaseRef.child('profile_picture').get();
    if (snapshot.exists) {
      return snapshot.value as String?;
    }
  } catch (e) {
    // Handle the error appropriately in the calling function
    throw Exception('Error retrieving profile picture: $e');
  }
  return null;
}

// Helper function to decode profile image
Future<Widget> decodeProfileImage(BuildContext context, String uid) async {
  const String defaultImagePath = 'assets/icon/icon.png'; // Path to your default image
  final double profileSize = 36.0; // Size of the profile picture

  try {
    String? base64String = await getProfilePicture(uid);
    if (base64String != null && base64String.isNotEmpty) {
      Uint8List imageBytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: BorderRadius.circular(profileSize / 2),
        child: Image.memory(
          imageBytes,
          width: profileSize,
          height: profileSize,
          fit: BoxFit.cover,
        ),
      );
    }
  } catch (e) {
    // Silently fallback to default image
    print('Error decoding profile picture: $e');
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(profileSize / 2),
    child: Image.asset(
      defaultImagePath,
      width: profileSize,
      height: profileSize,
      fit: BoxFit.cover,
    ),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  String _currentUserUid = '';
  Widget _profilePicWidget = Container(); // Placeholder for profile pic
  bool _isProfileLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserUid = user.uid;
      });
      _loadProfilePicture();
    }
  }

  void _loadProfilePicture() async {
    if (_currentUserUid.isNotEmpty) {
      try {
        Widget profileWidget = await decodeProfileImage(context, _currentUserUid);
        if (mounted) {
          setState(() {
            _profilePicWidget = profileWidget;
            _isProfileLoading = false;
          });
        }
      } catch (e) {
        print('Error loading profile picture: $e');
        if (mounted) {
          setState(() {
            _isProfileLoading = false;
          });
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsPage()),
    ).then((_) {
      // Reload profile picture when returning from settings
      _loadProfilePicture();
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

  // Updated widget list without the Settings page
  final List<Widget> _widgetOptions = <Widget>[
    HomePage(),
    TodayPage(),
    DetailsPage(),
    ChatPage(),
  ];

  // Page titles for the app bar
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
          automaticallyImplyLeading: false, // This removes the back button
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _pageTitles[_selectedIndex],
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            GestureDetector(
              onTap: _openSettings,
              child: Container(
                margin: EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: _isProfileLoading
                    ? Container(
                  width: 36,
                  height: 36,
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                )
                    : _profilePicWidget,
              ),
            ),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}