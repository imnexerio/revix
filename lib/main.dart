import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:retracker/AddLectureForm.dart';
import 'package:retracker/DetailsPage/DetailsPage.dart';
import 'package:retracker/LoginSignupPage/LoginPage.dart';
import 'package:retracker/ProfilePage/ProfilePage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'HomePage/HomePage.dart';
import 'SchedulePage/TodayPage.dart';
import 'Utils/SplashScreen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  // Custom green color palette
  static const MaterialColor customGreen = MaterialColor(
    0xFF2E7D32,
    <int, Color>{
      50: Color(0xFFE8F5E9),
      100: Color(0xFFC8E6C9),
      200: Color(0xFFA5D6A7),
      300: Color(0xFF81C784),
      400: Color(0xFF66BB6A),
      500: Color(0xFF4CAF50),
      600: Color(0xFF43A047),
      700: Color(0xFF388E3C),
      800: Color(0xFF2E7D32),
      900: Color(0xFF1B5E20),
    },
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'reTracker',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: customGreen,
        colorScheme: ColorScheme.light(
          // Primary colors
          primary: Color(0xFF2E7D32),      // Deep forest green
          primaryContainer: Color(0xFF43A047), // Slightly lighter green for containers

          // Secondary colors
          secondary: Color(0xFF66BB6A),    // Medium bright green
          secondaryContainer: Color(0xFF81C784), // Lighter container green

          // Tertiary colors
          tertiary: Color(0xFFA5D6A7),     // Soft pale green
          tertiaryContainer: Color(0xFFC8E6C9), // Very light green container

          // Surface and background colors
          surface: Colors.white,
          background: Color(0xFFF5F5F5),
          surfaceVariant: Color(0xFFE8F5E9), // Lightest green for variants

          // Error colors with green tint
          error: Color(0xFFE57373),
          errorContainer: Color(0xFFFFCDD2),

          // On colors
          onPrimary: Colors.white,
          onPrimaryContainer: Color(0xFF002200),
          onSecondary: Color(0xFF0D3A0D),
          onSecondaryContainer: Color(0xFF002200),
          onTertiary: Color(0xFF0D3A0D),
          onTertiaryContainer: Color(0xFF002200),
          onSurface: Color(0xFF1B5E20),     // Dark green for text
          onBackground: Color(0xFF2E7D32),   // Forest green for text
          onError: Colors.white,

          // Additional surface tints
          surfaceTint: Color(0xFF81C784),
        ),
        // Custom elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Enhanced card theme
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
        ),
        // Text theme with green accents
        textTheme: TextTheme(
          displayLarge: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: Color(0xFF388E3C), fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Color(0xFF2E7D32)),
          bodyMedium: TextStyle(color: Color(0xFF388E3C)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        primarySwatch: customGreen,
        colorScheme: ColorScheme.dark(
          // Primary colors
          primary: Color(0xFF81C784),      // Lighter green for dark theme
          primaryContainer: Color(0xFF66BB6A),

          // Secondary colors
          secondary: Color(0xFFA5D6A7),    // Very light green for contrast
          secondaryContainer: Color(0xFF81C784),

          // Tertiary colors
          tertiary: Color(0xFF4CAF50),
          tertiaryContainer: Color(0xFF388E3C),

          // Surface and background colors
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
          surfaceVariant: Color(0xFF1B5E20).withOpacity(0.1),

          // Error colors
          error: Color(0xFFE57373),
          errorContainer: Color(0xFF442727),

          // On colors
          onPrimary: Color(0xFF002200),
          onPrimaryContainer: Color(0xFFE8F5E9),
          onSecondary: Color(0xFF002200),
          onSecondaryContainer: Color(0xFFE8F5E9),
          onTertiary: Colors.white,
          onTertiaryContainer: Color(0xFFE8F5E9),
          onSurface: Color(0xFFA5D6A7),    // Light green for text
          onBackground: Color(0xFF81C784),  // Medium green for text
          onError: Colors.white,

          // Additional surface tints
          surfaceTint: Color(0xFF43A047),
        ),
        // Dark theme button style
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Dark theme card style
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
        ),
        // Dark theme text style
        textTheme: TextTheme(
          displayLarge: TextStyle(color: Color(0xFFA5D6A7), fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Color(0xFF81C784), fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Color(0xFFA5D6A7), fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Color(0xFF81C784)),
          bodyMedium: TextStyle(color: Color(0xFF66BB6A)),
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => isLoggedIn ? MyHomePage() : LoginPage(),
      },
      // home: isLoggedIn ? MyHomePage() : LoginPage(),
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

  // void _addLecture() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AddLectureForm();
  //     },
  //   );
  // }
//   void _addLecture() {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
//     ),
//     builder: (BuildContext context) {
//       return Container(
//         height: MediaQuery.of(context).size.height * 0.75, // Adjust the height as needed
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//         ),
//         child: AddLectureForm(),
//       );
//     },
//   );
// }
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
    ProfilePage()
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
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                label: 'Profile',
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