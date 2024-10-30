// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'CodeBar.dart';
//
// class SubjectsBar extends StatefulWidget {
//   @override
//   _SubjectsBarState createState() => _SubjectsBarState();
// }
//
// class _SubjectsBarState extends State<SubjectsBar> {
//   String? _selectedSubject;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeSelectedSubject();
//   }
//
//   Future<void> _initializeSelectedSubject() async {
//     try {
//       final data = await _fetchDataFromServer();
//       if (data.isNotEmpty) {
//         setState(() {
//           _selectedSubject = data.keys.first;
//         });
//       }
//     } catch (e) {
//       // print('Error initializing selected subject: $e');
//     }
//   }
//
//   Future<Map<String, dynamic>> _fetchDataFromServer() async {
//     DatabaseReference ref = FirebaseDatabase.instance.ref();
//     DataSnapshot snapshot = await ref.get();
//     if (snapshot.exists) {
//       final data = Map<String, dynamic>.from(snapshot.value as Map);
//       // print('Fetched data: $data'); // Print the fetched data
//       return data;
//     } else {
//       throw Exception('No data found on server');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: FutureBuilder<Map<String, dynamic>>(
//         future: _fetchDataFromServer(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No data found'));
//           } else {
//             final data = snapshot.data!;
//             final subjects = data.keys.toList();
//
//             return Column(
//               children: [
//                 if (_selectedSubject != null)
//                   Expanded(
//                     child: CodeBar(selectedSubject: _selectedSubject!),
//                   ),
//                 Container(
//                   height: 50.0,
//                   child: Padding(
//                     padding: EdgeInsets.symmetric(vertical: 4.0), // Add margin at top and bottom
//                     child: ListView.builder(
//                       scrollDirection: Axis.horizontal,
//                       itemCount: subjects.length,
//                       itemBuilder: (context, index) {
//                         final subject = subjects[index];
//                         return GestureDetector(
//                           onTap: () {
//                             setState(() {
//                               _selectedSubject = subject;
//                             });
//                           },
//                           child: Container(
//                             padding: EdgeInsets.all(5.0),
//                             margin: EdgeInsets.symmetric(horizontal: 6.0),
//                             decoration: BoxDecoration(
//                               color: _selectedSubject == subject
//                                   ? Theme.of(context).colorScheme.onPrimary
//                                   : Theme.of(context).colorScheme.primary,
//                               borderRadius: BorderRadius.circular(10.0),
//                             ),
//                             child: Center(
//                               child: Text(
//                                 subject,
//                                 style: TextStyle(
//                                   color: _selectedSubject == subject
//                                       ? Theme.of(context).colorScheme.primary
//                                       : Theme.of(context).colorScheme.onPrimary,
//                                   fontSize: 16,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 )
//               ],
//             );
//           }
//         },
//       ),
//     );
//   }
// }
//
// // import 'package:flutter/material.dart';
// // import 'package:firebase_database/firebase_database.dart';
// // import 'CodeBar.dart';
// //
// // class SubjectsBar extends StatefulWidget {
// //   @override
// //   _SubjectsBarState createState() => _SubjectsBarState();
// // }
// //
// // class _SubjectsBarState extends State<SubjectsBar> {
// //   String? _selectedSubject;
// //   Map<String, int> _missedRevisions = {};
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _initializeSelectedSubject();
// //   }
// //
// //   Future<void> _initializeSelectedSubject() async {
// //     try {
// //       final data = await _fetchDataFromServer();
// //       if (data.isNotEmpty) {
// //         setState(() {
// //           _selectedSubject = data.keys.first;
// //           _missedRevisions = _calculateMissedRevisions(data);
// //         });
// //       }
// //     } catch (e) {
// //       // Handle error
// //     }
// //   }
// //
// //   Future<Map<String, dynamic>> _fetchDataFromServer() async {
// //     DatabaseReference ref = FirebaseDatabase.instance.ref();
// //     DataSnapshot snapshot = await ref.get();
// //     if (snapshot.exists) {
// //       final data = Map<String, dynamic>.from(snapshot.value as Map);
// //       return data;
// //     } else {
// //       throw Exception('No data found on server');
// //     }
// //   }
// //
// //   Map<String, int> _calculateMissedRevisions(Map<String, dynamic> data) {
// //     Map<String, int> missedRevisions = {};
// //     data.forEach((subject, details) {
// //       int totalMissedRevisions = 0;
// //       details.forEach((subSubject, lectures) {
// //         lectures.forEach((lecture, lectureDetails) {
// //           totalMissedRevisions += (lectureDetails['missed_revision'] ?? 0) as int;
// //         });
// //       });
// //       missedRevisions[subject] = totalMissedRevisions;
// //     });
// //     return missedRevisions;
// //   }
// //
// //   Color _getColorForMissedRevisions(int missedRevisions) {
// //     if (missedRevisions == 0) {
// //       return Colors.green;
// //     } else if (missedRevisions >= 10) {
// //       return Colors.red;
// //     } else {
// //       int red = (255 * (missedRevisions / 10)).toInt();
// //       int green = 255 - red;
// //       return Color.fromARGB(255, red, green, 0);
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: FutureBuilder<Map<String, dynamic>>(
// //         future: _fetchDataFromServer(),
// //         builder: (context, snapshot) {
// //           if (snapshot.connectionState == ConnectionState.waiting) {
// //             return Center(child: CircularProgressIndicator());
// //           } else if (snapshot.hasError) {
// //             return Center(child: Text('Error: ${snapshot.error}'));
// //           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
// //             return Center(child: Text('No data found'));
// //           } else {
// //             final data = snapshot.data!;
// //             final subjects = data.keys.toList();
// //
// //             return Column(
// //               children: [
// //                 if (_selectedSubject != null)
// //                   Expanded(
// //                     child: CodeBar(selectedSubject: _selectedSubject!),
// //                   ),
// //                 Container(
// //                   height: 50.0,
// //                   child: Padding(
// //                     padding: EdgeInsets.symmetric(vertical: 4.0),
// //                     child: ListView.builder(
// //                       scrollDirection: Axis.horizontal,
// //                       itemCount: subjects.length,
// //                       itemBuilder: (context, index) {
// //                         final subject = subjects[index];
// //                         final missedRevisions = _missedRevisions[subject] ?? 0;
// //                         final color = _getColorForMissedRevisions(missedRevisions);
// //
// //                         return GestureDetector(
// //                           onTap: () {
// //                             setState(() {
// //                               _selectedSubject = subject;
// //                             });
// //                           },
// //                           child: Container(
// //                             padding: EdgeInsets.all(5.0),
// //                             margin: EdgeInsets.symmetric(horizontal: 6.0),
// //                             decoration: BoxDecoration(
// //                               color: color,
// //                               borderRadius: BorderRadius.circular(10.0),
// //                             ),
// //                             child: Center(
// //                               child: Text(
// //                                 subject,
// //                                 style: TextStyle(
// //                                   color: Theme.of(context).textTheme.bodyLarge?.color,
// //                                   fontSize: 16,
// //                                 ),
// //                               ),
// //                             ),
// //                           ),
// //                         );
// //                       },
// //                     ),
// //                   ),
// //                 )
// //               ],
// //             );
// //           }
// //         },
// //       ),
// //     );
// //   }
// // }

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'CodeBar.dart';

class SubjectsBar extends StatefulWidget {
  @override
  _SubjectsBarState createState() => _SubjectsBarState();
}

class _SubjectsBarState extends State<SubjectsBar> with SingleTickerProviderStateMixin {
  String? _selectedSubject;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _initializeSelectedSubject();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeSelectedSubject() async {
    try {
      final data = await _fetchDataFromServer();
      if (data.isNotEmpty) {
        setState(() {
          _selectedSubject = data.keys.first;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<Map<String, dynamic>> _fetchDataFromServer() async {
    DatabaseReference ref = FirebaseDatabase.instance.ref();
    DataSnapshot snapshot = await ref.get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    } else {
      throw Exception('No data found on server');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchDataFromServer(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No subjects found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final subjects = data.keys.toList();

          return Column(
            children: [
              if (_selectedSubject != null)
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: CodeBar(selectedSubject: _selectedSubject!),
                  ),
                ),
              Container(
                height: 70.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final isSelected = _selectedSubject == subject;

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        margin: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSubject = subject;
                              });
                              _controller.reset();
                              _controller.forward();
                            },
                            borderRadius: BorderRadius.circular(15.0),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(15.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Icon(
                                  Icons.book,
                                  size: 18,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  subject,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ));
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}