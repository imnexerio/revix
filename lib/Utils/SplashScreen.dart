import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/AnimatedSquareText.dart';
import '../main.dart';
import '../LoginSignupPage/LoginPage.dart';

class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  final bool isInitialized;
  
  const SplashScreen({
    Key? key, 
    required this.isLoggedIn, 
    required this.isInitialized
  }) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _subtitleController;
  late Animation<double> _subtitleAnimation;
  bool _animationComplete = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    // Controller for subtitle animation only
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Subtitle animation
    _subtitleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _subtitleController,
        curve: Curves.easeInOut,
      ),
    );

    // Start subtitle animation after square animation completes
    _scheduleSubtitleAnimation();
    
    // Mark animation complete after full logo animation (4 seconds minimum)
    _scheduleAnimationComplete();
  }

  void _scheduleSubtitleAnimation() {
    // Start subtitle animation after the square animation completes
    // Container animation (800ms) + Text animation (2000ms) = 2800ms total
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _subtitleController.forward();
      }
    });
  }

  void _scheduleAnimationComplete() {
    // Mark animation complete after 4 seconds (full logo animation)
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        setState(() {
          _animationComplete = true;
        });
        _tryNavigate();
      }
    });
  }

  void _tryNavigate() {
    // Navigate only when BOTH conditions are met:
    // 1. Animation is complete (4 seconds minimum for full logo)
    // 2. App is initialized (Firebase, Hive, etc. ready)
    if (_hasNavigated) return; // Prevent double navigation
    
    if (_animationComplete && widget.isInitialized) {
      _hasNavigated = true;
      _navigateToNextScreen();
    }
  }

  // React to widget updates (when parent calls setState with isInitialized = true)
  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInitialized != oldWidget.isInitialized && widget.isInitialized) {
      _tryNavigate();
    }
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    
    try {
      Widget nextScreen = widget.isLoggedIn 
          ? const MyHomePage() 
          : LoginPage();
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    } catch (e) {
      print('Navigation error: $e');
    }
  }

  @override
  void dispose() {
    _subtitleController.dispose();
    super.dispose();
  }@override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest,
            ],
          ),
        ),        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [                // Animated square container with text using the modular component
                AnimatedSquareText(
                  text: 'revix',
                  size: 180,
                  borderRadius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  textColor: const Color(0xFF06171F),
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  animationDuration: const Duration(milliseconds: 2000),
                  autoStart: true,
                ),
                const SizedBox(height: 40),
                // Animated subtitle outside the square
                AnimatedBuilder(
                  animation: _subtitleAnimation,
                  builder: (context, child) {
                    double animationValue = _subtitleAnimation.value.clamp(0.0, 1.0);
                    
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - animationValue)),
                      child: Opacity(
                        opacity: animationValue,
                        child: Container(
                          width: 180, // Same width as the square
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Track • Analyze • Improve',
                            textAlign: TextAlign.center, // Center the text within the container
                            style: GoogleFonts.nunito(
                              color: colorScheme.primary.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}