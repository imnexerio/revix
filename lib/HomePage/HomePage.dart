import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'DailyProgress.dart';
import 'MonthlyCalender.dart';
import 'SubjectDistributionPlot.dart';
import 'WeeklyProgress.dart';
import 'calculation_utils.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<Map<String, dynamic>> _getAllRecords() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    String uid = user.uid;

    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid/user_data');
      DataSnapshot snapshot = await ref.get();

      if (!snapshot.exists) {
        return {'allRecords': []};
      }

      Map<Object?, Object?> rawData = snapshot.value as Map<Object?, Object?>;

      List<Map<String, dynamic>> allRecords = [];

      rawData.forEach((subjectKey, subjectValue) {
        if (subjectValue is Map) {
          subjectValue.forEach((codeKey, codeValue) {
            if (codeValue is Map) {
              codeValue.forEach((recordKey, recordValue) {
                if (recordValue is Map) {
                  var record = {
                    'subject': subjectKey.toString(),
                    'subject_code': codeKey.toString(),
                    'lecture_no': recordKey.toString(),
                    'details': Map<String, dynamic>.from(recordValue),
                  };
                  allRecords.add(record);
                }
              });
            }
          });
        }
      });
      return {'allRecords': allRecords};
    } catch (e) {
      throw Exception('Failed to fetch records');
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;
    final cardPadding = screenWidth > 600 ? 24.0 : 16.0;

    return Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 40) / 2;
              return FutureBuilder<Map<String, dynamic>>(
                future: _getAllRecords(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          SizedBox(height: 16),
                          Text(
                            'Oops! Something went wrong',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!['allRecords']!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'No records yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  List<Map<String, dynamic>> allRecords = snapshot.data!['allRecords']!;
                  print(allRecords);
                  Map<String, int> subjectDistribution = calculateSubjectDistribution(allRecords);

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Performance Analytics',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                              ),
                            ),
                            SizedBox(height: 32),
                            // Overview Section
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Overview',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 16), // Add some space between the title and the content
                                  Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: _buildStatCard(
                                              'Total Lectures',
                                              calculateTotalLectures(allRecords).toString(),
                                              Color(0xFF6C63FF),
                                              cardWidth,
                                            ),
                                          ),
                                          SizedBox(width: 16), // Add some spacing between the cards
                                          Expanded(
                                            child: _buildStatCard(
                                              'Total Revisions',
                                              calculateTotalRevisions(allRecords).toString(),
                                              Color(0xFFDA5656),
                                              cardWidth,
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 16), // Add some space between the rows
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: _buildStatCard(
                                              "Percentage Completion",
                                              "${calculatePercentageCompletion(allRecords).toStringAsFixed(1)}%",
                                              getCompletionColor(calculatePercentageCompletion(allRecords)),
                                              cardWidth,
                                            ),
                                          ),
                                          SizedBox(width: 16), // Add some spacing between the cards
                                          Expanded(
                                            child: _buildStatCard(
                                              "Missed Revision",
                                              calculateMissedRevisions(allRecords).toString(),
                                              Color(0xFF008CC4),
                                              cardWidth,
                                            ),
                                          ),

                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 32),
                            // Progress Graph Section
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily Progress',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  SizedBox(
                                    height: 250,
                                    width: double.infinity,
                                    child: LineChart(createLineChartData(allRecords)),
                                  ),
                                  SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLegendItem('Lectures', Colors.blue, Icons.school),
                                      // _buildLegendItem('Revisions', Colors.orange, Icons.check_circle),
                                      SizedBox(width: 24),
                                      // _buildLegendItem('Lectures', Colors.blue, Icons.school),
                                      _buildLegendItem('Revisions', Colors.orange, Icons.check_circle),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 32),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weekly Progress',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  SizedBox(
                                    height: 250,
                                    width: double.infinity,
                                    child: BarChart(createBarChartWeeklyData(allRecords)),
                                  ),
                                  SizedBox(height: 24),

                                ],
                              ),
                            ),
                            SizedBox(height: 32),

                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Study Calendar',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  SizedBox(
                                    height: 500, // You can adjust this height as needed
                                    child: StudyCalendar(records: allRecords),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),

                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(cardPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subject Distribution',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  AspectRatio(
                                    aspectRatio: 1.3,
                                    child: PieChart(
                                      PieChartData(
                                        sections: createPieChartSections(subjectDistribution),
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  buildPieChartLegend(subjectDistribution, context),
                                ],
                              ),
                            ),

                            // Add this after the Subject Distribution Container in your HomePage widget
                            SizedBox(height: 32),// Add some bottom padding
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }



  Widget _buildStatCard(String title, String value, Color color, double width) {
    return Container(
      width: width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  Widget buildCalendarLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem('Learned', Colors.blue, Icons.school),
          _buildLegendItem('Revised', Colors.green, Icons.check_circle),
          _buildLegendItem('Missed', Colors.red, Icons.cancel),
          _buildLegendItem('Scheduled', Colors.orange, Icons.event),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 8,
          child: Icon(
            icon,
            color: Colors.white,
            size: 10,
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


}