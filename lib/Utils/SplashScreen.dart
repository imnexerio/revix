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
  final String _text = 'REVIX';
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );    // Create staggered animations for each letter
    _letterAnimations = List.generate(_text.length, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.15, // Stagger each letter by 150ms
            (index * 0.15) + 0.4, // Each letter animation lasts 400ms
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
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _startAnimation();
  }

  void _startAnimation() {
    _controller.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 800), () {
        _navigateToHome();
      });
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
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

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
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,              children: [
                // Animated text with individual letter pop-ins
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _text.split('').asMap().entries.map((entry) {
                      int index = entry.key;
                      String letter = entry.value;
                      
                      return AnimatedBuilder(
                        animation: _letterAnimations[index],
                        builder: (context, child) {
                          // Clamp the animation value to prevent overflow
                          double animationValue = _letterAnimations[index].value.clamp(0.0, 1.0);
                          
                          return Transform.scale(
                            scale: animationValue,
                            child: Opacity(
                              opacity: animationValue,                              child: Text(
                                letter,
                                style: GoogleFonts.nunito(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 58,
                                  letterSpacing: 1.5,
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
                const SizedBox(height: 30),                // Animated subtitle
                AnimatedBuilder(
                  animation: _subtitleAnimation,
                  builder: (context, child) {
                    // Clamp the animation value to prevent overflow
                    double animationValue = _subtitleAnimation.value.clamp(0.0, 1.0);
                    
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - animationValue)),
                      child: Opacity(
                        opacity: animationValue,
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
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.primary.withOpacity(0.8),
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w500,
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