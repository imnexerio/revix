import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

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

      // Print the raw data
      print('Raw data: $rawData');

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

  Map<String, int> _calculateSubjectDistribution(List<Map<String, dynamic>> records) {
    Map<String, int> subjectCounts = {};

    for (var record in records) {
      String subject = record['subject'];
      subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
    }

    return subjectCounts;
  }

  List<PieChartSectionData> _createPieChartSections(Map<String, int> subjectCounts) {
    final colors = [
      Colors.purple,
      Colors.green,
      Colors.red,
      Colors.yellow,
      Colors.blue,
    ];

    List<PieChartSectionData> sections = [];
    int totalLectures = subjectCounts.values.fold(0, (sum, count) => sum + count);
    int colorIndex = 0;

    subjectCounts.forEach((subject, count) {
      double percentage = (count / totalLectures) * 100;
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: percentage,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return sections;
  }

  Widget _buildPieChartLegend(Map<String, int> subjectCounts) {
    final colors = [
      Colors.purple,
      Colors.green,
      Colors.red,
      Colors.yellow,
      Colors.blue,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: subjectCounts.entries.map((entry) {
        int index = subjectCounts.keys.toList().indexOf(entry.key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '${entry.key} (${entry.value})',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;
    final cardPadding = screenWidth > 600 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
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
                            'No records scheduled yet',
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
                  Map<String, int> subjectDistribution = _calculateSubjectDistribution(allRecords);

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
                                              _calculateTotalLectures(allRecords).toString(),
                                              Color(0xFF6C63FF),
                                              cardWidth,
                                            ),
                                          ),
                                          SizedBox(width: 16), // Add some spacing between the cards
                                          Expanded(
                                            child: _buildStatCard(
                                              'Total Revisions',
                                              _calculateTotalRevisions(allRecords).toString(),
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
                                          "${_calculatePercentageCompltion(allRecords).toStringAsFixed(1)}%",
                                          _getCompletionColor(_calculatePercentageCompltion(allRecords)),
                                          cardWidth,
                                        ),
                                      ),
                                          SizedBox(width: 16), // Add some spacing between the cards
                                          Expanded(
                                            child: _buildStatCard(
                                              "Missed Revision",
                                              _calculateMissedrevisions(allRecords).toString(),
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
                                    'Progress Graph',
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
                                    child: LineChart(_createLineChartData(allRecords)),
                                  ),
                                  SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLegendItem('Lectures', Color(0xFF6C63FF)),
                                      SizedBox(width: 24),
                                      _buildLegendItem('Revisions', Color(0xFF00C48C)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 32),
                            // Subject Distribution Section
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
                                        sections: _createPieChartSections(subjectDistribution),
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  _buildPieChartLegend(subjectDistribution),
                                ],
                              ),
                            ),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _calculateTotalLectures(List<Map<String, dynamic>> records) {
    return records.where((record) => record['details']['date_learnt'] != null).length;
  }

  int _calculateTotalRevisions(List<Map<String, dynamic>> records) {
    int totalRevisions = 0;
    for (var record in records) {
      if (record['details']['no_revision'] != null ) {
        totalRevisions += (record['details']['no_revision'] as int);
      }
    }
    return totalRevisions;
  }

  int _calculateMissedrevisions(List<Map<String, dynamic>> records) {
    int missedRevisionsCount = 0;

    for (var record in records) {
      if (record.containsKey('details') && record['details'] is Map) {
        var details = record['details'] as Map;
        if (details.containsKey('missed_revision') && details['missed_revision'] > 0) {
          missedRevisionsCount++;
        }
      }
    }

    return missedRevisionsCount;
  }

  Color _getCompletionColor(double percentage) {
    if (percentage <= 50) {
      return Color.lerp(Color(0xFFC40000), Color(0xFFFFEB3B), percentage / 50)!; // Red to Yellow
    } else {
      return Color.lerp(Color(0xFFFFEB3B), Color(0xFF00C853), (percentage - 50) / 50)!; // Yellow to Green
    }
  }

  double _calculatePercentageCompltion(List<Map<String, dynamic>> records) {
    int completedLectures = records.where((record) => record['details']['date_learnt'] != null && record['details']['lecture_type'] == 'Lectures').length;
    int totalLectures = 200;
    double percentageCompletion = (completedLectures / totalLectures) * 100;
    return percentageCompletion;
  }

  LineChartData _createLineChartData(List<Map<String, dynamic>> records) {
    Map<String, int> lectureCounts = {};
    Map<String, int> revisionCounts = {};

    DateTime today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      DateTime date = today.subtract(Duration(days: i));
      String dateStr = date.toIso8601String().split('T')[0];
      lectureCounts[dateStr] = 0;
      revisionCounts[dateStr] = 0;
    }

    for (var record in records) {
      String? dateLearnt = record['details']['date_learnt'];
      String? dateRevised = record['details']['date_revised'];
      if (dateLearnt != null && lectureCounts.containsKey(dateLearnt)) {
        lectureCounts[dateLearnt] = lectureCounts[dateLearnt]! + 1;
      }
      if (dateRevised != null && revisionCounts.containsKey(dateRevised)) {
        revisionCounts[dateRevised] = revisionCounts[dateRevised]! + 1;
      }
    }

    List<FlSpot> lectureSpots = [];
    List<FlSpot> revisionSpots = [];

    int index = 6; // Start from the rightmost position
    lectureCounts.forEach((date, count) {
      lectureSpots.add(FlSpot(index.toDouble(), count.toDouble()));
      index--;
    });

    index = 6; // Start from the rightmost position
    revisionCounts.forEach((date, count) {
      revisionSpots.add(FlSpot(index.toDouble(), count.toDouble()));
      index--;
    });

    return LineChartData(
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(value.toInt().toString())),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
            DateTime date = today.subtract(Duration(days: 6 - value.toInt()));
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                date.day.toString(), // Only show the day
                style: TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            );
          }),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: lectureSpots,
          isCurved: true,
          color: Color(0xFF6C63FF),
          barWidth: 6,
          isStrokeCapRound: true,
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: revisionSpots,
          isCurved: true,
          color: Color(0xFF00C48C),
          barWidth: 4,
          isStrokeCapRound: true,

          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}