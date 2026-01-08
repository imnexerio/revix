import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:revix/HomePage/review_calculations.dart';
import 'package:revix/Utils/customSnackBar_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/FirebaseDatabaseService.dart';
import '../Utils/GuestAuthService.dart';
import '../Utils/LocalDatabaseService.dart';
import 'DailyProgressCard.dart';
import 'ProgressCalendarCard.dart';
import 'CategoryDistributionCard.dart';
import 'WeeklyProgressCard.dart';
import 'calculation_utils.dart';
import 'completion_utils.dart';
import 'entry_calculations.dart';
import 'missed_calculations.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final UnifiedDatabaseService _recordService = UnifiedDatabaseService();
  Stream<Map<String, dynamic>>? _recordsStream;

  String _entryViewType = 'Total';
  String _reviewViewType = 'Total';
  String _completionViewType = 'Total';
  String _missedViewType = 'Total';

  String _selectedEntryType = 'All'; // Changed default to 'All'
  List<String> _availableEntryTypes = ['All']; // Added 'All' instead of 'Lectures'

  Map<String, Set<String>> _selectedTrackingTypesMap = {
    'entry': {},
    'review': {},
    'completion': {},
    'missed': {},
  };  Map<String, int> _completionTargets = {};
  int get _customCompletionTarget {
    final target = _completionTargets[_selectedEntryType] ?? 200;
    return target;
  }
  
  bool _isLoadingTargets = true;

  Size? _previousSize;

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _recordService.initialize();
    _recordsStream = _recordService.allRecordsStream;
    _initializeData();
  }

  // Initialize all data in proper order
  Future<void> _initializeData() async {
    await _loadSavedPreferences();
    await _fetchTrackingTypesAndTargetFromFirebase();
    await _loadAvailableEntryTypes();
    
    if (mounted) {
      setState(() {
        _isLoadingTargets = false;
      });
    }
  }  // Load saved preferences from SharedPreferences
  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _entryViewType = prefs.getString('entryViewType') ?? 'Total';
        _reviewViewType = prefs.getString('reviewViewType') ?? 'Total';
        _completionViewType = prefs.getString('completionViewType') ?? 'Total';
        _missedViewType = prefs.getString('missedViewType') ?? 'Total';
        _selectedEntryType = prefs.getString('selectedEntryType') ?? 'All'; // Changed default to 'All'
      });
    }
  }

  // Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('entryViewType', _entryViewType);
    await prefs.setString('reviewViewType', _reviewViewType);
    await prefs.setString('completionViewType', _completionViewType);
    await prefs.setString('missedViewType', _missedViewType);
    await prefs.setString('selectedEntryType', _selectedEntryType);
  }

  // Modified method to load available entry types
  Future<void> _loadAvailableEntryTypes() async {
    try {
      final databaseService = FirebaseDatabaseService();
      final trackingTypes = await databaseService.fetchCustomTrackingTypes();
      setState(() {
        // Ensure 'All' is always the first option and then add other tracking types
        List<String> types = ['All']; // Start with 'All'
        if (trackingTypes.isNotEmpty) {
          // Add all types except 'All' if it already exists in trackingTypes
          types.addAll(trackingTypes.where((type) => type != 'All'));
        }
        _availableEntryTypes = types;
      });
    } catch (e) {
      // Handle error, keeping default with 'All'
      setState(() {
        _availableEntryTypes = ['All'];
      });
    }
  }

  // Cycle through available entry types
  void _cycleEntryType() {
    if (_availableEntryTypes.isEmpty) return;

    setState(() {
      int currentIndex = _availableEntryTypes.indexOf(_selectedEntryType);
      int nextIndex = (currentIndex + 1) % _availableEntryTypes.length;
      _selectedEntryType = _availableEntryTypes[nextIndex];
    });
    _savePreferences(); // Save when entry type changes
  }  Future<void> _fetchTrackingTypesAndTargetFromFirebase() async {
    try {
      if (await GuestAuthService.isGuestMode()) {
        // Use local database for guest users
        final localDb = LocalDatabaseService();
        final homePageData = await localDb.getProfileData('home_page', defaultValue: {});
          if (homePageData.isNotEmpty && homePageData is Map) {
          // Safe type casting for local database data
          final homePageMap = Map<String, dynamic>.from(homePageData);
          final selectedTypesRaw = homePageMap['selectedTrackingTypes'];
          final completionTargetsRaw = homePageMap['completionTargets'];
          
          // Convert to proper Map<String, dynamic> if needed
          Map<String, dynamic> selectedTypes = {};
          Map<String, dynamic> completionTargets = {};
          
          if (selectedTypesRaw != null) {
            if (selectedTypesRaw is Map) {
              selectedTypes = Map<String, dynamic>.from(selectedTypesRaw);
            }
          }
          
          if (completionTargetsRaw != null) {
            if (completionTargetsRaw is Map) {
              completionTargets = Map<String, dynamic>.from(completionTargetsRaw);
            }
          }

          if (mounted) {
            setState(() {
              selectedTypes.forEach((key, value) {
                if (_selectedTrackingTypesMap.containsKey(key)) {
                  List<dynamic> valueList = value as List<dynamic>;
                  _selectedTrackingTypesMap[key] = valueList.map((item) => item.toString()).toSet();
                }
              });

              completionTargets.forEach((key, value) {
                final parsedValue = int.tryParse(value.toString()) ?? 200;
                _completionTargets[key] = parsedValue;
              });
            });
          }
        }
      } else {
        // Use centralized Firebase service for authenticated users
        final firebaseService = FirebaseDatabaseService();
        final homePageData = await firebaseService.fetchHomePageSettings();

        if (homePageData.isNotEmpty) {
          // Safe type casting for Firebase data
          final selectedTypesRaw = homePageData['selectedTrackingTypes'];
          final completionTargetsRaw = homePageData['completionTargets'];
          
          // Convert to proper Map<String, dynamic> if needed
          Map<String, dynamic> selectedTypes = {};
          Map<String, dynamic> completionTargets = {};
          
          if (selectedTypesRaw != null) {
            if (selectedTypesRaw is Map) {
              selectedTypes = Map<String, dynamic>.from(selectedTypesRaw);
            }
          }
          
          if (completionTargetsRaw != null) {
            if (completionTargetsRaw is Map) {
              completionTargets = Map<String, dynamic>.from(completionTargetsRaw);
            }
          }

          if (mounted) {
            setState(() {
              selectedTypes.forEach((key, value) {
                if (_selectedTrackingTypesMap.containsKey(key)) {
                  List<dynamic> valueList = value as List<dynamic>;
                  _selectedTrackingTypesMap[key] = valueList.map((item) => item.toString()).toSet();
                }
              });

              completionTargets.forEach((key, value) {
                final parsedValue = int.tryParse(value.toString()) ?? 200;
                _completionTargets[key] = parsedValue;
              });
            });
          }
        }
      }
    } catch (e) {
      // Handle error silently
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

            List<Map<String, dynamic>> filteredRecords = _selectedEntryType == 'All'
                ? allRecords
                : allRecords.where((record) {
              return record['details']['entry_type'] == _selectedEntryType;
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
                                  onTap: _cycleEntryType,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Overview: $_selectedEntryType',
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
                                    if (_selectedEntryType == 'All') {
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
                                            'Set Target for $_selectedEntryType',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Enter your completion target for $_selectedEntryType:',
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
                                                  await firebaseService.saveHomePageCompletionTarget(_selectedEntryType, targetValue);
                                                  setState(() {
                                                    _completionTargets[_selectedEntryType] = newTarget;
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
                // Extra scrollable space for bottom navigation
                const SliverPadding(padding: EdgeInsets.only(bottom: 88.0)),
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
                _getEntryValue(filteredRecords, _entryViewType),
                const Color(0xFF6C63FF),
                _entryViewType,
                    () => _cycleViewType(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Reviewed',
                _getReviewValue(filteredRecords, _reviewViewType),
                const Color(0xFFDA5656),
                _reviewViewType,
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
      _entryViewType = _getNextViewType(_entryViewType);
      _reviewViewType = _getNextViewType(_reviewViewType);
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

  String _getEntryValue(List<Map<String, dynamic>> records, String viewType) {
    switch (viewType) {
      case 'Total':
        return calculateTotalEntries(records).toString();
      case 'Monthly':
        return calculateMonthlyEntries(records).toString();
      case 'Weekly':
        return calculateWeeklyEntries(records).toString();
      case 'Daily':
        return calculateDailyEntries(records).toString();
      default:
        return calculateTotalEntries(records).toString();
    }
  }

  String _getReviewValue(List<Map<String, dynamic>> records, String viewType) {
    switch (viewType) {
      case 'Total':
        return calculateTotalReviews(records).toString();
      case 'Monthly':
        return calculateMonthlyReviews(records).toString();
      case 'Weekly':
        return calculateWeeklyReviews(records).toString();
      case 'Daily':
        return calculateDailyReviews(records).toString();
      default:
        return calculateTotalReviews(records).toString();
    }
  }

  String _getCompletionValue(List<Map<String, dynamic>> records, String viewType) {
    int target = _selectedEntryType == 'All' ? _calculateAllCompletionPercentage(records) : _customCompletionTarget;

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
        return calculateMissedReviews(records).toString();
      case 'Monthly':
        return calculateMonthlyMissed(records).toString();
      case 'Weekly':
        return calculateWeeklyMissed(records).toString();
      case 'Daily':
        return calculateDailyMissed(records).toString();
      default:
        return calculateMissedReviews(records).toString();
    }
  }

  Widget _buildSingleRowStatsGrid(List<Map<String, dynamic>> filteredRecords) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Initiatives',
            _getEntryValue(filteredRecords, _entryViewType),
            const Color(0xFF6C63FF),
            _entryViewType,
                () => _cycleViewType(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Reviewed',
            _getReviewValue(filteredRecords, _reviewViewType),
            const Color(0xFFDA5656),
            _reviewViewType,
                () => _cycleViewType(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
              "Completion Percentage",
              _getCompletionValue(filteredRecords, _completionViewType),
              getCompletionColor(calculatePercentageCompletion(filteredRecords,
                  _selectedEntryType == 'All' ? _calculateAllCompletionPercentage(filteredRecords) : _customCompletionTarget)),
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
    int completedEntries = records.where((record) =>
    record['details']['date_initiated'] != null
    ).length;
    double percentageCompletion = customCompletionTarget > 0
        ? (completedEntries / customCompletionTarget) * 100
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
                onTitleTap: _cycleEntryType,  // Pass the callback function
                selectedEntryType: _selectedEntryType,  // Pass the selected type
              ),
              const SizedBox(height: 32),
              buildCategoryDistributionCard(
                subjectDistribution,
                cardPadding,
                context,
                onTitleTap: _cycleEntryType,
                selectedEntryType: _selectedEntryType,
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
                onTitleTap: _cycleEntryType,
                selectedEntryType: _selectedEntryType,
              ),
              const SizedBox(height: 32),
              buildProgressCalendarCard(
                filteredRecords,
                cardPadding,
                context,
                onTitleTap: _cycleEntryType,
                selectedEntryType: _selectedEntryType,
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
          onTitleTap: _cycleEntryType,
          selectedEntryType: _selectedEntryType,
        ),
        const SizedBox(height: 24),
        buildWeeklyProgressCard(
          filteredRecords,
          cardPadding,
          context,
          onTitleTap: _cycleEntryType,
          selectedEntryType: _selectedEntryType,
        ),
        const SizedBox(height: 24),
        buildProgressCalendarCard(
          filteredRecords,
          cardPadding,
          context,
          onTitleTap: _cycleEntryType,
          selectedEntryType: _selectedEntryType,
        ),
        const SizedBox(height: 24),
        buildCategoryDistributionCard(
          subjectDistribution,
          cardPadding,
          context,
          onTitleTap: _cycleEntryType,
          selectedEntryType: _selectedEntryType,
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