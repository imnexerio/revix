import 'package:flutter/material.dart';
import '../LoginSignupPage/UrlLauncher.dart';
import '../Utils/CustomSnackBar.dart';

class AboutPage extends StatelessWidget {
  final Future<String> Function() getAppVersion;
  final Future<String> Function() fetchReleaseNotes;

  AboutPage({required this.getAppVersion, required this.fetchReleaseNotes});

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
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    child: ClipOval(
                      child: Stack(
                        children: [
                          ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            ),
                            child: Image.asset(
                              'assets/icon/icon.png', // Path to your app icon
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  const SizedBox(height: 5),
                  FutureBuilder<String>(
                    future: getAppVersion(),
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
                                UrlLauncher.launchURL(context, 'https://github.com/imnexerio/retracker');
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
                      future: fetchReleaseNotes(),
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
                  Container(
                    width: 200, // Set the desired width
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
            ),
          );
        },
      ),
    );
  }
}