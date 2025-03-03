import 'package:flutter/material.dart';

import '../LoginSignupPage/UrlLauncher.dart';

void showAboutBottomSheet(BuildContext context, Future<String> Function() getAppVersion, Future<String> Function() fetchReleaseNotes) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Container(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight * 0.4,
              maxHeight: constraints.maxHeight * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ],
                            ),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              child: ClipOval(
                                child: Stack(
                                  children: [
                                    ColorFiltered(
                                      colorFilter: ColorFilter.mode(
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
                            SizedBox(height: 10),
                            Text(
                              'reTracker',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            SizedBox(height: 5),
                            FutureBuilder<String>(
                              future: getAppVersion(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return Text('Error loading version');
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
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                        icon: ImageIcon(
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
                            )
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: FutureBuilder<String>(
                              future: fetchReleaseNotes(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
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
                        ),
                        SizedBox(height: 20),
                        Container(
                          width: 200, // Set the desired width
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                            child: Text(
                              'I Understand',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}