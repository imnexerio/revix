import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _letterAnimations;
  late Animation<double> _subtitleAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _containerAnimation;
  final String _text = 'revix';
    @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Container animation - starts with app icon size and expands
    _containerAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    // Scale animation for the entire content
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Create staggered animations for each letter
    _letterAnimations = List.generate(_text.length, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.3 + (index * 0.1), // Stagger each letter
            0.3 + (index * 0.1) + 0.3, // Each letter animation duration
            curve: Curves.bounceOut,
          ),
        ),
      );
    });

    // Subtitle animation starts after letters
    _subtitleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.8, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start animation immediately when splash screen loads
    _startAnimation();
    
    // Set minimum splash screen duration and navigate after app is ready
    _scheduleNavigation();
  }

  void _startAnimation() {
    _controller.forward();
  }
  void _scheduleNavigation() {
    // Wait for at least 3.5 seconds to show the full animation and give app time to load
    Future.delayed(const Duration(milliseconds: 3500), () {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }  @override
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
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated square container with text
                    Transform.scale(
                      scale: _containerAnimation.value,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFFC), // Cyan background for square
                          borderRadius: BorderRadius.circular(40), // Round-edged square
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _text.split('').asMap().entries.map((entry) {
                                int index = entry.key;
                                String letter = entry.value;
                                
                                return AnimatedBuilder(
                                  animation: _letterAnimations[index],
                                  builder: (context, child) {
                                    double animationValue = _letterAnimations[index].value.clamp(0.0, 1.0);
                                    
                                    return Transform.scale(
                                      scale: animationValue,
                                      child: Opacity(
                                        opacity: animationValue,
                                        child: Text(
                                          letter,
                                          style: GoogleFonts.nunito(
                                            color: const Color(0xFF06171F), // Dark text color
                                            fontWeight: FontWeight.w800,
                                            fontSize: 48,
                                            letterSpacing: 2.0,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Animated subtitle outside the square
                    Transform.translate(
                      offset: Offset(0, 20 * (1 - _subtitleAnimation.value.clamp(0.0, 1.0))),
                      child: Opacity(
                        opacity: _subtitleAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
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
                            style: GoogleFonts.nunito(
                              color: colorScheme.primary.withOpacity(0.8),
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}