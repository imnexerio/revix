import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/UnifiedDatabaseService.dart';
import 'LectureBar.dart';

class CodeBar extends StatefulWidget {
  final String selectedCategory;

  CodeBar({required this.selectedCategory});

  @override
  _CodeBarState createState() => _CodeBarState();
}

class _CodeBarState extends State<CodeBar> with SingleTickerProviderStateMixin {
  String? _selectedCategoryCode;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  Stream<Map<String, dynamic>>? _categoriesStream;
  Map<String, dynamic>? _categoryData;
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
    _categoriesStream = getCategoriesStream();

    // Then initialize data
    _initializeSelectedCategoryCode();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeSelectedCategoryCode() async {
    try {
      final data = await fetchCategoriesAndSubCategories();

      setState(() {
        _categoryData = data;
        _isLoading = false;

        // Set the initial code for the selected subject
        if (data['subCategories'].containsKey(widget.selectedCategory)) {
          final codes = data['subCategories'][widget.selectedCategory] as List<dynamic>;
          if (codes.isNotEmpty) {
            _selectedCategoryCode = codes.first.toString();
            _controller.forward();
          }
        }
      });
    } catch (e) {
      // print('Error initializing Sub Category: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(CodeBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the subject has changed, we need to update the selected code
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      // Reset the selected code
      setState(() {
        _selectedCategoryCode = null;
      });

      // Check if we already have data loaded
      if (_categoryData != null &&
          _categoryData!['subCategories'] != null &&
          _categoryData!['subCategories'][widget.selectedCategory] != null) {

        final codes = _categoryData!['subCategories'][widget.selectedCategory] as List<dynamic>;
        if (codes.isNotEmpty) {
          setState(() {
            _selectedCategoryCode = codes.first.toString();
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
        stream: _categoriesStream,
        initialData: _categoryData,
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
              !snapshot.data!['subCategories'].containsKey(widget.selectedCategory) ||
              (snapshot.data!['subCategories'][widget.selectedCategory] as List).isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No sub category found for ${widget.selectedCategory}',
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
          final codes = snapshot.data!['subCategories'][widget.selectedCategory] as List<dynamic>;

          // If we have data but no selected subject, select the first one
          if (_selectedCategoryCode == null && codes.isNotEmpty) {
            _selectedCategoryCode = codes.first.toString();
            // Don't call setState here as it can cause rebuild loops
          }

          // If selected subject no longer exists in the updated list
          if (_selectedCategoryCode != null && !codes.contains(_selectedCategoryCode)) {
            if (codes.isNotEmpty) {
              _selectedCategoryCode = codes.first.toString();
              // Don't call setState here as it can cause rebuild loops
            } else {
              _selectedCategoryCode = null;
            }
          }

          return Stack(
            children: [
              if (_selectedCategoryCode != null)
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
                          selectedCategory: widget.selectedCategory,
                          selectedCategoryCode: _selectedCategoryCode!,
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
                        final isSelected = _selectedCategoryCode == code;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryCode = code;
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