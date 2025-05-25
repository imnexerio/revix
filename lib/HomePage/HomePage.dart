import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:retracker/HomePage/revision_calculations.dart';
import 'package:retracker/Utils/customSnackBar_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/FetchTypesUtils.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/LocalDatabaseService.dart';
import 'DailyProgressCard.dart';
import 'ProgressCalendarCard.dart';
import 'SubjectDistributionCard.dart';
import 'WeeklyProgressCard.dart';
import 'calculation_utils.dart';
import 'completion_utils.dart';
import 'lecture_calculations.dart';
import 'missed_calculations.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final UnifiedDatabaseService _recordService = UnifiedDatabaseService();
  Stream<Map<String, dynamic>>? _recordsStream;

  String _lectureViewType = 'Total';
  String _revisionViewType = 'Total';
  String _completionViewType = 'Total';
  String _missedViewType = 'Total';

  String _selectedLectureType = 'All'; // Changed default to 'All'
  List<String> _availableLectureTypes = ['All']; // Added 'All' instead of 'Lectures'

  Map<String, Set<String>> _selectedTrackingTypesMap = {
    'lecture': {},
    'revision': {},
    'completion': {},
    'missed': {},
  };

  Map<String, int> _completionTargets = {};
  int get _customCompletionTarget => _completionTargets[_selectedLectureType] ?? 200;

  Size? _previousSize;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _recordService.initialize();
    _recordsStream = _recordService.allRecordsStream;
    _loadSavedPreferences();
    _fetchTrackingTypesAndTargetFromFirebase();
    _loadAvailableLectureTypes();
  }

  // Load saved preferences from SharedPreferences
  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _lectureViewType = prefs.getString('lectureViewType') ?? 'Total';
      _revisionViewType = prefs.getString('revisionViewType') ?? 'Total';
      _completionViewType = prefs.getString('completionViewType') ?? 'Total';
      _missedViewType = prefs.getString('missedViewType') ?? 'Total';
      _selectedLectureType = prefs.getString('selectedLectureType') ?? 'All'; // Changed default to 'All'
    });
  }

  // Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('lectureViewType', _lectureViewType);
    await prefs.setString('revisionViewType', _revisionViewType);
    await prefs.setString('completionViewType', _completionViewType);
    await prefs.setString('missedViewType', _missedViewType);
    await prefs.setString('selectedLectureType', _selectedLectureType);
  }

  // Modified method to load available lecture types
  Future<void> _loadAvailableLectureTypes() async {
    try {
      final trackingTypes = await FetchtrackingTypeUtils.fetchtrackingType();
      setState(() {
        // Ensure 'All' is always the first option and then add other tracking types
        List<String> types = ['All']; // Start with 'All'
        if (trackingTypes.isNotEmpty) {
          // Add all types except 'All' if it already exists in trackingTypes
          types.addAll(trackingTypes.where((type) => type != 'All'));
        }
        _availableLectureTypes = types;
      });
    } catch (e) {
      // Handle error, keeping default with 'All'
      setState(() {
        _availableLectureTypes = ['All'];
      });
    }
  }

  // Cycle through available lecture types
  void _cycleLectureType() {
    if (_availableLectureTypes.isEmpty) return;

    setState(() {
      int currentIndex = _availableLectureTypes.indexOf(_selectedLectureType);
      int nextIndex = (currentIndex + 1) % _availableLectureTypes.length;
      _selectedLectureType = _availableLectureTypes[nextIndex];
    });
    _savePreferences(); // Save when lecture type changes
  }
  Future<void> _fetchTrackingTypesAndTargetFromFirebase() async {
    try {
      if (await GuestAuthService.isGuestMode()) {
        // Use local database for guest users
        final localDb = LocalDatabaseService();
        final homePageData = await localDb.getProfileData('home_page', defaultValue: {});
        
        if (homePageData.isNotEmpty && homePageData is Map<String, dynamic>) {
          final selectedTypes = homePageData['selectedTrackingTypes'] as Map<String, dynamic>? ?? {};
          final completionTargets = homePageData['completionTargets'] as Map<String, dynamic>? ?? {};

          setState(() {
            selectedTypes.forEach((key, value) {
              if (_selectedTrackingTypesMap.containsKey(key)) {
                List<dynamic> valueList = value as List<dynamic>;
                _selectedTrackingTypesMap[key] = valueList.map((item) => item.toString()).toSet();
              }
            });

            completionTargets.forEach((key, value) {
              _completionTargets[key] = int.tryParse(value.toString()) ?? 200;
            });
          });
        }
      } else {
        // Use centralized Firebase service for authenticated users
        final firebaseService = FirebaseDatabaseService();
        final homePageData = await firebaseService.fetchHomePageSettings();

        if (homePageData.isNotEmpty) {
          final selectedTypes = homePageData['selectedTrackingTypes'] as Map<String, dynamic>? ?? {};
          final completionTargets = homePageData['completionTargets'] as Map<String, dynamic>? ?? {};

          setState(() {
            selectedTypes.forEach((key, value) {
              if (_selectedTrackingTypesMap.containsKey(key)) {
                List<dynamic> valueList = value as List<dynamic>;
                _selectedTrackingTypesMap[key] = valueList.map((item) => item.toString()).toSet();
              }
            });

            completionTargets.forEach((key, value) {
              _completionTargets[key] = int.tryParse(value.toString()) ?? 200;
            });
          });
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _recordService.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      _recordService.initialize();
    }
  }

  @override
  void dispose() {
    _recordService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentSize = MediaQuery.of(context).size;
    final screenWidth = currentSize.width;

    final rebuildLayout = _previousSize == null ||
        (_previousSize!.width != currentSize.width &&
            (_crossesBreakpoint(_previousSize!.width, currentSize.width, 600) ||
                _crossesBreakpoint(_previousSize!.width, currentSize.width, 900)));

    _previousSize = currentSize;
    final cardPadding = screenWidth > 600 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0.0),
        child: StreamBuilder(
          stream: _recordsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return _buildErrorWidget();
            } else if (!snapshot.hasData || snapshot.data!['allRecords']!.isEmpty) {
              return _buildEmptyWidget();
            }

            List<Map<String, dynamic>> allRecords = snapshot.data!['allRecords']!;

            List<Map<String, dynamic>> filteredRecords = _selectedLectureType == 'All'
                ? allRecords
                : allRecords.where((record) {
              return record['details']['lecture_type'] == _selectedLectureType;
            }).toList();

            Map<String, int> subjectDistribution = calculateSubjectDistribution(filteredRecords);

            return CustomScrollView(
              key: const PageStorageKey('homeScrollView'),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Make the Overview title clickable
                                GestureDetector(
                                  onTap: _cycleLectureType,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Overview: $_selectedLectureType',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.titleLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.swap_horiz,
                                        size: 16,
                                        color: Theme.of(context).textTheme.titleLarge?.color,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () {
                                    if (_selectedLectureType == 'All') {
                                      customSnackBar_error(context: context, message: 'Cannot set target for combined view');
                                      return;
                                    }

                                    final TextEditingController textFieldController = TextEditingController(
                                      text: _customCompletionTarget.toString(),
                                    );

                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Text(
                                            'Set Target for $_selectedLectureType',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Enter your completion target for $_selectedLectureType:',
                                              ),
                                              const SizedBox(height: 16),
                                              TextField(
                                                controller: textFieldController,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                decoration: InputDecoration(
                                                  prefixIcon: const Icon(Icons.flag_outlined),
                                                  hintText: "Enter your target",
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.grey.withOpacity(0.1),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              style: TextButton.styleFrom(),
                                              child: const Text('Cancel'),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text('Save'),                                              onPressed: () async {
                                                final String targetValue = textFieldController.text;
                                                if (targetValue.isNotEmpty) {
                                                  final int newTarget = int.parse(targetValue);

                                                  final firebaseService = FirebaseDatabaseService();
                                                  await firebaseService.saveHomePageCompletionTarget(_selectedLectureType, targetValue);
                                                  setState(() {
                                                    _completionTargets[_selectedLectureType] = newTarget;
                                                  });
                                                }
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ],
                                          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            rebuildLayout
                                ? screenWidth > 900
                                ? _buildSingleRowStatsGrid(filteredRecords)
                                : _buildTwoByTwoStatsGrid(filteredRecords)
                                : screenWidth > 900
                                ? _buildSingleRowStatsGrid(filteredRecords)
                                : _buildTwoByTwoStatsGrid(filteredRecords),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: rebuildLayout
                      ? screenWidth > 900
                      ? _buildTwoColumnLayout(filteredRecords, subjectDistribution, cardPadding)
                      : _buildSingleColumnLayout(filteredRecords, subjectDistribution, cardPadding)
                      : screenWidth > 900
                      ? _buildTwoColumnLayout(filteredRecords, subjectDistribution, cardPadding)
                      : _buildSingleColumnLayout(filteredRecords, subjectDistribution, cardPadding),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _crossesBreakpoint(double oldWidth, double newWidth, double breakpoint) {
    return (oldWidth <= breakpoint && newWidth > breakpoint) ||
        (oldWidth > breakpoint && newWidth <= breakpoint);
  }

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

  Widget _buildTwoByTwoStatsGrid(List<Map<String, dynamic>> filteredRecords) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Initiatives',
                _getLectureValue(filteredRecords, _lectureViewType),
                const Color(0xFF6C63FF),
                _lectureViewType,
                    () => _cycleViewType(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Reviewed',
                _getRevisionValue(filteredRecords, _revisionViewType),
                const Color(0xFFDA5656),
                _revisionViewType,
                    () => _cycleViewType(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Completion Percentage",
                _getCompletionValue(filteredRecords, _completionViewType),
                getCompletionColor(calculatePercentageCompletion(filteredRecords, _customCompletionTarget)),
                _completionViewType,
                    () => _cycleViewType(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                "Missed",
                _getMissedValue(filteredRecords, _missedViewType),
                const Color(0xFF008CC4),
                _missedViewType,
                    () => _cycleViewType(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _cycleViewType() {
    setState(() {
      _lectureViewType = _getNextViewType(_lectureViewType);
      _revisionViewType = _getNextViewType(_revisionViewType);
      _completionViewType = _getNextViewType(_completionViewType);
      _missedViewType = _getNextViewType(_missedViewType);
    });
    _savePreferences(); // Save when view type changes
  }

  String _getNextViewType(String currentType) {
    switch (currentType) {
      case 'Total':
        return 'Monthly';
      case 'Monthly':
        return 'Weekly';
      case 'Weekly':
        return 'Daily';
      case 'Daily':
        return 'Total';
      default:
        return 'Total';
    }
  }

  String _getLectureValue(List<Map<String, dynamic>> records, String viewType) {
    switch (viewType) {
      case 'Total':
        return calculateTotalLectures(records).toString();
      case 'Monthly':
        return calculateMonthlyLectures(records).toString();
      case 'Weekly':
        return calculateWeeklyLectures(records).toString();
      case 'Daily':
        return calculateDailyLectures(records).toString();
      default:
        return calculateTotalLectures(records).toString();
    }
  }

  String _getRevisionValue(List<Map<String, dynamic>> records, String viewType) {
    switch (viewType) {
      case 'Total':
        return calculateTotalRevisions(records).toString();
      case 'Monthly':
        return calculateMonthlyRevisions(records).toString();
      case 'Weekly':
        return calculateWeeklyRevisions(records).toString();
      case 'Daily':
        return calculateDailyRevisions(records).toString();
      default:
        return calculateTotalRevisions(records).toString();
    }
  }

  String _getCompletionValue(List<Map<String, dynamic>> records, String viewType) {
    int target = _selectedLectureType == 'All' ? _calculateAllCompletionPercentage(records) : _customCompletionTarget;

    switch (viewType) {
      case 'Total':
        return "${calculatePercentageCompletion(records, target).toStringAsFixed(1)}%";
      case 'Monthly':
        return "${calculateMonthlyCompletion(records, target).toStringAsFixed(1)}%";
      case 'Weekly':
        return "${calculateWeeklyCompletion(records, target).toStringAsFixed(1)}%";
      case 'Daily':
        return "${calculateDailyCompletion(records, target).toStringAsFixed(1)}%";
      default:
        return "${calculatePercentageCompletion(records, target).toStringAsFixed(1)}%";
    }
  }

  int _calculateAllCompletionPercentage(List<Map<String, dynamic>> records) {
    if (_completionTargets.isEmpty) return 200;

    int totalTarget = 0;
    _completionTargets.forEach((type, target) {
      if (type != 'All') {
        totalTarget += target;
      }
    });

    return totalTarget > 0 ? totalTarget : 200;
  }

  String _getMissedValue(List<Map<String, dynamic>> records, String viewType) {
    switch (viewType) {
      case 'Total':
        return calculateMissedRevisions(records).toString();
      case 'Monthly':
        return calculateMonthlyMissed(records).toString();
      case 'Weekly':
        return calculateWeeklyMissed(records).toString();
      case 'Daily':
        return calculateDailyMissed(records).toString();
      default:
        return calculateMissedRevisions(records).toString();
    }
  }

  Widget _buildSingleRowStatsGrid(List<Map<String, dynamic>> filteredRecords) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Initiatives',
            _getLectureValue(filteredRecords, _lectureViewType),
            const Color(0xFF6C63FF),
            _lectureViewType,
                () => _cycleViewType(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Reviewed',
            _getRevisionValue(filteredRecords, _revisionViewType),
            const Color(0xFFDA5656),
            _revisionViewType,
                () => _cycleViewType(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
              "Completion Percentage",
              _getCompletionValue(filteredRecords, _completionViewType),
              getCompletionColor(calculatePercentageCompletion(filteredRecords,
                  _selectedLectureType == 'All' ? _calculateAllCompletionPercentage(filteredRecords) : _customCompletionTarget)),
              _completionViewType,
                  () => _cycleViewType()
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
              "Missed",
              _getMissedValue(filteredRecords, _missedViewType),
              const Color(0xFF008CC4),
              _missedViewType,
                  () => _cycleViewType()
          ),
        ),
      ],
    );
  }

  double calculatePercentageCompletion(List<Map<String, dynamic>> records, int customCompletionTarget) {
    int completedLectures = records.where((record) =>
    record['details']['date_learnt'] != null
    ).length;
    double percentageCompletion = customCompletionTarget > 0
        ? (completedLectures / customCompletionTarget) * 100
        : 0;
    return percentageCompletion;
  }

  Widget _buildTwoColumnLayout(
      List<Map<String, dynamic>> filteredRecords,
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
              buildDailyProgressCard(
                filteredRecords,
                cardPadding,
                context,
                onTitleTap: _cycleLectureType,  // Pass the callback function
                selectedLectureType: _selectedLectureType,  // Pass the selected type
              ),
              const SizedBox(height: 32),
              buildSubjectDistributionCard(
                subjectDistribution,
                cardPadding,
                context,
                onTitleTap: _cycleLectureType,
                selectedLectureType: _selectedLectureType,
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right column
        Expanded(
          flex: 1,
          child: Column(
            children: [
              buildWeeklyProgressCard(
                filteredRecords,
                cardPadding,
                context,
                onTitleTap: _cycleLectureType,
                selectedLectureType: _selectedLectureType,
              ),
              const SizedBox(height: 32),
              buildProgressCalendarCard(
                filteredRecords,
                cardPadding,
                context,
                onTitleTap: _cycleLectureType,
                selectedLectureType: _selectedLectureType,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumnLayout(
      List<Map<String, dynamic>> filteredRecords,
      Map<String, int> subjectDistribution,
      double cardPadding) {
    return Column(
      children: [
        buildDailyProgressCard(
          filteredRecords,
          cardPadding,
          context,
          onTitleTap: _cycleLectureType,
          selectedLectureType: _selectedLectureType,
        ),
        const SizedBox(height: 24),
        buildWeeklyProgressCard(
          filteredRecords,
          cardPadding,
          context,
          onTitleTap: _cycleLectureType,
          selectedLectureType: _selectedLectureType,
        ),
        const SizedBox(height: 24),
        buildProgressCalendarCard(
          filteredRecords,
          cardPadding,
          context,
          onTitleTap: _cycleLectureType,
          selectedLectureType: _selectedLectureType,
        ),
        const SizedBox(height: 24),
        buildSubjectDistributionCard(
          subjectDistribution,
          cardPadding,
          context,
          onTitleTap: _cycleLectureType,
          selectedLectureType: _selectedLectureType,
        ),
      ],
    );
  }


  Widget _buildStatCard(String title, String value, Color color, String viewType, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  viewType,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
      ),
    );
  }
}