import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/subject_utils.dart';
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

    _initializeSelectedSubjectCode();

    // Subscribe to the stream
    _subjectsStream = getSubjectsStream();

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeSelectedSubjectCode() async {
    try {
      final data = await fetchSubjectsAndCodes();
      if (data['subjects'].isNotEmpty) {
        setState(() {
          _selectedSubjectCode = data['subjects'].first;
          _subjectData = data;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }


  @override
  void didUpdateWidget(CodeBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the subject has changed, we need to update the selected code
    if (oldWidget.selectedSubject != widget.selectedSubject) {
      // Reset the selected code
      _selectedSubjectCode = null;

      // Check if we already have data loaded
      if (_subjectData != null &&
          _subjectData!['subjectCodes'] != null &&
          _subjectData!['subjectCodes'][widget.selectedSubject] != null) {

        final codes = _subjectData!['subjectCodes'][widget.selectedSubject] as List<String>;
        if (codes.isNotEmpty) {
          setState(() {
            _selectedSubjectCode = codes.first;
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
        body: StreamBuilder<Map<String, dynamic>>(
        // Use the stream instead of future
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
              SizedBox(height: 16),
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
      } else if (!snapshot.hasData || snapshot.data!['subjects'].isEmpty) {
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

    // Prepare list of codes for the selected subject
    final codes = _subjectData!['subjectCodes'][widget.selectedSubject] as List<String>;

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
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                itemCount: codes.length,
                itemBuilder: (context, index) {
                  final code = codes[index];
                  final isSelected = _selectedSubjectCode == code;

                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 6.0),
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
                              SizedBox(width: 8),
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
}}

