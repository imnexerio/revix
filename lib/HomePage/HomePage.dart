import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../SchedulePage/LegendItem.dart';
import 'DailyProgress.dart';
import '../Utils/FetchRecord.dart';
import 'MonthlyCalender.dart';
import 'SubjectDistributionPlot.dart';
import 'WeeklyProgress.dart';
import 'calculation_utils.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final FetchRecord _recordService = FetchRecord();
  // Cache the fetched data
  Future<Map<String, dynamic>>? _recordsFuture;

  // Add MediaQuery size caching
  Size? _previousSize;

  @override
  bool get wantKeepAlive => true; // Keep state alive when widget is not visible

  @override
  void initState() {
    super.initState();
    // Initialize the future in initState
    _recordsFuture = _recordService.getAllRecords();
  }

  Future<void> _refreshData() async {
    setState(() {
      _recordsFuture = _recordService.getAllRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final currentSize = MediaQuery.of(context).size;
    final screenWidth = currentSize.width;

    // Only rebuild the layout if the screen size has changed significantly
    final rebuildLayout = _previousSize == null ||
        (_previousSize!.width != currentSize.width &&
            (_crossesBreakpoint(_previousSize!.width, currentSize.width, 600) ||
                _crossesBreakpoint(_previousSize!.width, currentSize.width, 900)));

    // Update the previous size
    _previousSize = currentSize;

    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;
    final cardPadding = screenWidth > 600 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16.0),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _recordsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return _buildErrorWidget();
              } else if (!snapshot.hasData || snapshot.data!['allRecords']!.isEmpty) {
                return _buildEmptyWidget();
              }

              List<Map<String, dynamic>> allRecords = snapshot.data!['allRecords']!;
              Map<String, int> subjectDistribution = calculateSubjectDistribution(allRecords);

              return CustomScrollView(
                // Use a unique key for CustomScrollView that doesn't depend on data
                // but still preserves scroll position
                key: const PageStorageKey('homeScrollView'),
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
                        const SizedBox(height: 32),

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
                                offset: const Offset(0, 4),
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
                              const SizedBox(height: 16),

                              // Responsive grid layout for stats - only rebuild if needed
                              rebuildLayout
                                  ? screenWidth > 900
                                  ? _buildSingleRowStatsGrid(allRecords)
                                  : _buildTwoByTwoStatsGrid(allRecords)
                                  : screenWidth > 900
                                  ? _buildSingleRowStatsGrid(allRecords)
                                  : _buildTwoByTwoStatsGrid(allRecords),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Dynamic layout for main sections - only rebuild if needed
                  SliverToBoxAdapter(
                    child: rebuildLayout
                        ? screenWidth > 900
                        ? _buildTwoColumnLayout(allRecords, subjectDistribution, cardPadding)
                        : _buildSingleColumnLayout(allRecords, subjectDistribution, cardPadding)
                        : screenWidth > 900
                        ? _buildTwoColumnLayout(allRecords, subjectDistribution, cardPadding)
                        : _buildSingleColumnLayout(allRecords, subjectDistribution, cardPadding),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Check if the width crosses any of our breakpoints
  bool _crossesBreakpoint(double oldWidth, double newWidth, double breakpoint) {
    return (oldWidth <= breakpoint && newWidth > breakpoint) ||
        (oldWidth > breakpoint && newWidth <= breakpoint);
  }

  // Error widget - extracted to reduce build method complexity
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
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
  }

  // Empty widget - extracted to reduce build method complexity
  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
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

  // Two-by-two grid for medium screens
  Widget _buildTwoByTwoStatsGrid(List<Map<String, dynamic>> allRecords) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Lectures',
                calculateTotalLectures(allRecords).toString(),
                const Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Revisions',
                calculateTotalRevisions(allRecords).toString(),
                const Color(0xFFDA5656),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Percentage Completion",
                "${calculatePercentageCompletion(allRecords).toStringAsFixed(1)}%",
                getCompletionColor(calculatePercentageCompletion(allRecords)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                "Missed Revision",
                calculateMissedRevisions(allRecords).toString(),
                const Color(0xFF008CC4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Single row layout for larger screens
  Widget _buildSingleRowStatsGrid(List<Map<String, dynamic>> allRecords) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Lectures',
            calculateTotalLectures(allRecords).toString(),
            const Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Revisions',
            calculateTotalRevisions(allRecords).toString(),
            const Color(0xFFDA5656),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            "Percentage Completion",
            "${calculatePercentageCompletion(allRecords).toStringAsFixed(1)}%",
            getCompletionColor(calculatePercentageCompletion(allRecords)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            "Missed Revision",
            calculateMissedRevisions(allRecords).toString(),
            const Color(0xFF008CC4),
          ),
        ),
      ],
    );
  }

  // Two column layout for larger screens
  Widget _buildTwoColumnLayout(
      List<Map<String, dynamic>> allRecords,
      Map<String, int> subjectDistribution,
      double cardPadding) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildDailyProgressCard(allRecords, cardPadding),
              const SizedBox(height: 32),
              _buildSubjectDistributionCard(subjectDistribution, cardPadding),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildWeeklyProgressCard(allRecords, cardPadding),
              const SizedBox(height: 32),
              _buildProgressCalendarCard(allRecords, cardPadding),
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
      double cardPadding) {
    return Column(
      children: [
        _buildDailyProgressCard(allRecords, cardPadding),
        const SizedBox(height: 24),
        _buildWeeklyProgressCard(allRecords, cardPadding),
        const SizedBox(height: 24),
        _buildProgressCalendarCard(allRecords, cardPadding),
        const SizedBox(height: 24),
        _buildSubjectDistributionCard(subjectDistribution, cardPadding),
      ],
    );
  }

  Widget _buildDailyProgressCard(List<Map<String, dynamic>> allRecords, double cardPadding) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: LineChart(createLineChartData(allRecords)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              LegendItem(label: 'Lectures', color: Colors.blue, icon: Icons.school),
              LegendItem(label: 'Revisions', color: Colors.green, icon: Icons.check_circle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressCard(List<Map<String, dynamic>> allRecords, double cardPadding) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: BarChart(createBarChartWeeklyData(allRecords)),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        LegendItem(label: 'Lectures', color: Colors.blue, icon: Icons.school),
        LegendItem(label: 'Revisions', color: Colors.green, icon: Icons.check_circle),
        LegendItem(label: 'Missed', color: Colors.red, icon: Icons.cancel),
        LegendItem(label: 'Scheduled', color: Colors.orange, icon: Icons.schedule),
      ],
    );
  }

  Widget _buildProgressCalendarCard(List<Map<String, dynamic>> allRecords, double cardPadding) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
          const SizedBox(height: 24),
          SizedBox(
            height: 750,
            child: StudyCalendar(
              key: const PageStorageKey('monthlyCalendar'),
              records: allRecords,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSubjectDistributionCard(Map<String, int> subjectDistribution, double cardPadding) {
    // Get the screen width to calculate responsive sizes
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate dynamic radius based on screen width
    final bool isSmallScreen = screenWidth < 600;
    final double chartRadius = isSmallScreen ? 80 : 100;
    final double centerRadius = isSmallScreen ? 60 : 80;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          // Use LayoutBuilder to make pie chart responsive to its container
          LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 600,
                  child: PieChart(
                    PieChartData(
                      sections: createPieChartSections(
                        subjectDistribution,
                        chartRadius,
                        Theme.of(context),
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: centerRadius,
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          // Could implement hover effects or selection here
                        },
                        enabled: true,
                      ),
                    ),
                  ),
                );
              }
          ),
          const SizedBox(height: 32),
          Center(
            child: buildPieChartLegend(subjectDistribution, context),
          ),
        ],
      ),
    );
  }


  Widget buildPieChartLegend(Map<String, int> subjectCounts, BuildContext context) {
    // Modern color palette - same as in createPieChartSections
    final colors = [
      const Color(0xFF5038BC),  // Deep purple
      const Color(0xFF4ECDC4),  // Teal
      const Color(0xFFFF6B6B),  // Coral
      const Color(0xFFFFD166),  // Yellow
      const Color(0xFF118AB2),  // Blue
      const Color(0xFFEF8354),  // Orange
      const Color(0xFF06D6A0),  // Mint
      const Color(0xFFDA627D),  // Pink
    ];

    // Calculate total count for percentage calculation
    int totalCount = subjectCounts.values.fold(0, (sum, count) => sum + count);

    // Sort entries by count for better visualization (matching the pie chart order)
    var sortedEntries = subjectCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: sortedEntries.asMap().entries.map((mapEntry) {
          int index = mapEntry.key;
          var entry = mapEntry.value;
          double percentage = totalCount > 0 ? (entry.value / totalCount * 100) : 0;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.key} (${percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 8),
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
}