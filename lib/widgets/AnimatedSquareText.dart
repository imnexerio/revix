import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedSquareText extends StatefulWidget {
  final String text;
  final double size;
  final double borderRadius;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Duration animationDuration;
  final bool autoStart;
  final bool loop;
  final Duration? loopDelay;
  final VoidCallback? onAnimationComplete;
  final List<BoxShadow>? boxShadow;
  
  const AnimatedSquareText({
    Key? key,
    required this.text,
    this.size = 280,
    this.borderRadius = 40,
    this.backgroundColor = const Color(0xFF00FFFC),
    this.textColor = const Color(0xFF06171F),
    this.fontSize = 48,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = 2.0,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.autoStart = true,
    this.loop = false,
    this.loopDelay = const Duration(milliseconds: 1000),
    this.onAnimationComplete,
    this.boxShadow,
  }) : super(key: key);

  @override
  _AnimatedSquareTextState createState() => _AnimatedSquareTextState();
}

class _AnimatedSquareTextState extends State<AnimatedSquareText>
    with TickerProviderStateMixin {
  late AnimationController _containerController;
  late AnimationController _textController;
  late List<Animation<double>> _letterAnimations;
  late Animation<double> _scaleAnimation;
  late Animation<double> _containerAnimation;
  
  bool _hasContainerAnimated = false;

  @override
  void initState() {
    super.initState();
    
    // Separate controllers for container and text
    _containerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _textController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // Container animation - starts small and expands (only once)
    _containerAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _containerController,
        curve: Curves.easeOutBack,
      ),
    );

    // Scale animation for the text content
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    // Create staggered animations for each letter
    _letterAnimations = List.generate(widget.text.length, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _textController,
          curve: Interval(
            0.2 + (index * 0.1), // Stagger each letter
            0.2 + (index * 0.1) + 0.3, // Each letter animation duration
            curve: Curves.bounceOut,
          ),
        ),
      );
    });

    // Listen for container animation completion
    _containerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hasContainerAnimated = true;
        // Start text animation immediately after container animation
        _textController.forward();
      }
    });

    // Listen for text animation completion
    _textController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.onAnimationComplete != null) {
          widget.onAnimationComplete!();
        }
        
        // Handle looping - only reset and replay text animation
        if (widget.loop && mounted) {
          Future.delayed(widget.loopDelay ?? const Duration(milliseconds: 1000), () {
            if (mounted) {
              _textController.reset();
              _textController.forward();
            }
          });
        }
      }
    });

    // Auto start animation if enabled
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startAnimation();
      });
    }
  }

  /// Start the animation
  void startAnimation() {
    if (mounted) {
      if (!_hasContainerAnimated) {
        _containerController.forward();
      } else {
        _textController.forward();
      }
    }
  }

  /// Reset the animation
  void resetAnimation() {
    if (mounted) {
      _containerController.reset();
      _textController.reset();
      _hasContainerAnimated = false;
    }
  }

  /// Reverse the animation
  void reverseAnimation() {
    if (mounted) {
      _textController.reverse();
    }
  }

  @override
  void dispose() {
    _containerController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_containerController, _textController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _containerAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: widget.boxShadow ?? [
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
                  children: widget.text.split('').asMap().entries.map((entry) {
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
                                color: widget.textColor,
                                fontWeight: widget.fontWeight,
                                fontSize: widget.fontSize,
                                letterSpacing: widget.letterSpacing,
                                height: 1.0,
                              ),
                            ),
                          ),                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Extension to provide easy access to animation controller
extension AnimatedSquareTextExtension on AnimatedSquareText {
  /// Create a global key to access the widget's methods
  static GlobalKey<_AnimatedSquareTextState> createKey() {
    return GlobalKey<_AnimatedSquareTextState>();
  }
}

/// Helper methods for controlling the animation externally
class AnimatedSquareController {
  final GlobalKey<_AnimatedSquareTextState> _key;
  
  AnimatedSquareController(this._key);
  
  void startAnimation() {
    _key.currentState?.startAnimation();
  }
  
  void resetAnimation() {
    _key.currentState?.resetAnimation();
  }
  
  void reverseAnimation() {
    _key.currentState?.reverseAnimation();
  }
  
  bool get isAnimating {
    return _key.currentState?._textController.isAnimating ?? false;
  }
  
  bool get isCompleted {
    return _key.currentState?._textController.isCompleted ?? false;
  }
}
