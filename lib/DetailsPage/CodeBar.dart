import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/UnifiedDatabaseService.dart';
import 'LectureBar.dart';

class CodeBar extends StatefulWidget {
  final String selectedSubject;

  CodeBar({required this.selectedSubject});

  @override
  _CodeBarState createState() => _CodeBarState();
}

class _CodeBarState extends State<CodeBar> with SingleTickerProviderStateMixin {
  String? _selectedSubjectCode;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  Stream<Map<String, dynamic>>? _subjectsStream;
  Map<String, dynamic>? _subjectData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Subscribe to the stream first
    _subjectsStream = getSubjectsStream();

    // Then initialize data
    _initializeSelectedSubjectCode();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeSelectedSubjectCode() async {
    try {
      final data = await fetchSubjectsAndCodes();

      setState(() {
        _subjectData = data;
        _isLoading = false;

        // Set the initial code for the selected subject
        if (data['subjectCodes'].containsKey(widget.selectedSubject)) {
          final codes = data['subjectCodes'][widget.selectedSubject] as List<dynamic>;
          if (codes.isNotEmpty) {
            _selectedSubjectCode = codes.first.toString();
            _controller.forward();
          }
        }
      });
    } catch (e) {
      // print('Error initializing subject code: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(CodeBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the subject has changed, we need to update the selected code
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      // Reset the selected code
      setState(() {
        _selectedSubjectCode = null;
      });

      // Check if we already have data loaded
      if (_subjectData != null &&
          _subjectData!['subjectCodes'] != null &&
          _subjectData!['subjectCodes'][widget.selectedSubject] != null) {

        final codes = _subjectData!['subjectCodes'][widget.selectedSubject] as List<dynamic>;
        if (codes.isNotEmpty) {
          setState(() {
            _selectedSubjectCode = codes.first.toString();
          });
          _controller.reset();
          _controller.forward();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: 3,
        ),
      )
          : StreamBuilder<Map<String, dynamic>>(
        stream: _subjectsStream,
        initialData: _subjectData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No records found try adding some',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData ||
              !snapshot.data!['subjectCodes'].containsKey(widget.selectedSubject) ||
              (snapshot.data!['subjectCodes'][widget.selectedSubject] as List).isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No subject code found for ${widget.selectedSubject}',
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

          // Prepare list of codes for the selected subject
          final codes = snapshot.data!['subjectCodes'][widget.selectedSubject] as List<dynamic>;

          // If we have data but no selected subject, select the first one
          if (_selectedSubjectCode == null && codes.isNotEmpty) {
            _selectedSubjectCode = codes.first.toString();
            // Don't call setState here as it can cause rebuild loops
          }

          // If selected subject no longer exists in the updated list
          if (_selectedSubjectCode != null && !codes.contains(_selectedSubjectCode)) {
            if (codes.isNotEmpty) {
              _selectedSubjectCode = codes.first.toString();
              // Don't call setState here as it can cause rebuild loops
            } else {
              _selectedSubjectCode = null;
            }
          }

          return Stack(
            children: [
              if (_selectedSubjectCode != null)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height * 0.1,
                    ),
                    child: ScaleTransition(
                      scale: _slideAnimation,
                      child: FadeTransition(
                        opacity: _slideAnimation,
                        child: LectureBar(
                          selectedSubject: widget.selectedSubject,
                          selectedSubjectCode: _selectedSubjectCode!,
                        ),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 70.0,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: codes.length,
                      itemBuilder: (context, index) {
                        final code = codes[index].toString();
                        final isSelected = _selectedSubjectCode == code;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSubjectCode = code;
                                });
                                _controller.reset();
                                _controller.forward();
                              },
                              borderRadius: BorderRadius.circular(15.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
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
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.code,
                                      size: 18,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      code,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimary
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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