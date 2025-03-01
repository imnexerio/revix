import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'DailyProgress.dart';
import 'FetchRecord.dart';
import 'MonthlyCalender.dart';
import 'SubjectDistributionPlot.dart';
import 'WeeklyProgress.dart';
import 'calculation_utils.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FetchRecord _recordService = FetchRecord();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;
    final cardPadding = screenWidth > 600 ? 24.0 : 16.0;
    final isLargeScreen = screenWidth > 900;
    final isMediumScreen = screenWidth > 600 && screenWidth <= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _recordService.getAllRecords().then((result) {
              print(result);
              return result;
            }),
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

                        // Overview Section with responsive grid
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
                              SizedBox(height: 16),

                              // Responsive grid layout for stats
                              screenWidth > 900
                                ? _buildSingleRowStatsGrid(allRecords)
                                : _buildTwoByTwoStatsGrid(allRecords),
                            ],
                          ),
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Dynamic layout for main sections
                  SliverToBoxAdapter(
                    child: isLargeScreen
                        ? _buildTwoColumnLayout(allRecords, subjectDistribution, cardPadding, context)
                        : _buildSingleColumnLayout(allRecords, subjectDistribution, cardPadding, context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Two-by-two grid for larger screens
  Widget _buildTwoByTwoStatsGrid(List<Map<String, dynamic>> allRecords) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Lectures',
                calculateTotalLectures(allRecords).toString(),
                Color(0xFF6C63FF),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Revisions',
                calculateTotalRevisions(allRecords).toString(),
                Color(0xFFDA5656),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Percentage Completion",
                "${calculatePercentageCompletion(allRecords).toStringAsFixed(1)}%",
                getCompletionColor(calculatePercentageCompletion(allRecords)),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                "Missed Revision",
                calculateMissedRevisions(allRecords).toString(),
                Color(0xFF008CC4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Single row layout for smaller screens
  Widget _buildSingleRowStatsGrid(List<Map<String, dynamic>> allRecords) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Lectures',
            calculateTotalLectures(allRecords).toString(),
            Color(0xFF6C63FF),
          ),
        ),
        SizedBox(width: 16), // Add space between cards
        Expanded(
          child: _buildStatCard(
            'Total Revisions',
            calculateTotalRevisions(allRecords).toString(),
            Color(0xFFDA5656),
          ),
        ),
        SizedBox(width: 16), // Add space between cards
        Expanded(
          child: _buildStatCard(
            "Percentage Completion",
            "${calculatePercentageCompletion(allRecords).toStringAsFixed(1)}%",
            getCompletionColor(calculatePercentageCompletion(allRecords)),
          ),
        ),
        SizedBox(width: 16), // Add space between cards
        Expanded(
          child: _buildStatCard(
            "Missed Revision",
            calculateMissedRevisions(allRecords).toString(),
            Color(0xFF008CC4),
          ),
        ),
      ],
    );
  }
  // Two column layout for larger screens
  Widget _buildTwoColumnLayout(
      List<Map<String, dynamic>> allRecords,
      Map<String, int> subjectDistribution,
      double cardPadding,
      BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildDailyProgressCard(allRecords, cardPadding, context),
              SizedBox(height: 32),
              _buildSubjectDistributionCard(subjectDistribution, cardPadding, context),
            ],
          ),
        ),
        SizedBox(width: 32),
        // Right column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildWeeklyProgressCard(allRecords, cardPadding, context),
              SizedBox(height: 32),
              _buildProgressCalendarCard(allRecords, cardPadding, context),
            ],
          ),
        ),
      ],
    );
  }

  // Single column layout for smaller screens
  Widget _buildSingleColumnLayout(
      List<Map<String, dynamic>> allRecords,
      Map<String, int> subjectDistribution,
      double cardPadding,
      BuildContext context) {
    return Column(
      children: [
        _buildDailyProgressCard(allRecords, cardPadding, context),
        SizedBox(height: 32),
        _buildWeeklyProgressCard(allRecords, cardPadding, context),
        SizedBox(height: 32),
        _buildProgressCalendarCard(allRecords, cardPadding, context),
        SizedBox(height: 32),
        _buildSubjectDistributionCard(subjectDistribution, cardPadding, context),
        SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDailyProgressCard(List<Map<String, dynamic>> allRecords, double cardPadding, BuildContext context) {
    return Container(
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
              SizedBox(width: 24),
              _buildLegendItem('Revisions', Colors.orange, Icons.check_circle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressCard(List<Map<String, dynamic>> allRecords, double cardPadding, BuildContext context) {
    return Container(
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
          SizedBox(height: 16),
          _buildLegend(context),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Lectures', Colors.blue, context),
        SizedBox(width: 16),
        _legendItem('Revisions', Colors.green, context),
        SizedBox(width: 16),
        _legendItem('Missed', Colors.red, context),
        SizedBox(width: 16),
        _legendItem('Scheduled', Colors.orange, context),
      ],
    );
  }

  Widget _legendItem(String label, Color color, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCalendarCard(List<Map<String, dynamic>> allRecords, double cardPadding, BuildContext context) {
    return Container(
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
            'Progress Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 500, // Adjusted height
            child: StudyCalendar(records: allRecords),
          ),
          SizedBox(height: 16),
          buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildSubjectDistributionCard(Map<String, int> subjectDistribution, double cardPadding, BuildContext context) {
    return Container(
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
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
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