import 'package:flutter/material.dart';
import '../LoginSignupPage/UrlLauncher.dart';
import '../Utils/CustomSnackBar.dart';
import '../Utils/VersionChecker.dart';
import '../widgets/AnimatedSquareText.dart';

class AboutPage extends StatefulWidget {
  final Future<String> Function() getAppVersion;
  final Future<String> Function() fetchReleaseNotes;

  AboutPage({required this.getAppVersion, required this.fetchReleaseNotes});

  @override
  _AboutPageState createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _showLogo = false;

  @override
  void initState() {
    super.initState();
    
    // Show logo with a delay to trigger animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showLogo = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(                      child: _showLogo ? AnimatedSquareText(
                        text: 'revix',
                        size: 80,
                        borderRadius: 40, // Half of size to make it perfectly round
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        textColor: const Color(0xFF06171F),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        animationDuration: const Duration(milliseconds: 1500),
                        autoStart: true, // Auto start when widget is created
                        loop: false, // No looping for About page
                        boxShadow: [], // Remove shadow since container already has it
                      ) : Container(), // Empty container when not showing
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'revix',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 5),                  FutureBuilder<String>(
                    future: widget.getAppVersion(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return const Text('Error loading version');
                      } else {
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'v${snapshot.data}',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).colorScheme.secondary),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'FOSS',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const ImageIcon(
                                AssetImage('assets/github.png'), // Path to your GitHub icon
                              ),
                              onPressed: () {
                                UrlLauncher.launchURL(context, 'https://github.com/imnexerio/revix');
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: FutureBuilder<String>(
                      future: widget.fetchReleaseNotes(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return Text(
                            'Error loading release notes',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          );
                        } else {
                          return Text(
                            snapshot.data!,
                            style: Theme.of(context).textTheme.bodyLarge,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            VersionChecker.checkForUpdatesManually(context);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.system_update,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Check Updates',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            customSnackBar(
                              context: context,
                              message: 'Thank you for using revix!',
                            );
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                          child: const Text(
                            'I Understand',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}