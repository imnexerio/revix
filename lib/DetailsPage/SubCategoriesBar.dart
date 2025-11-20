import 'package:flutter/material.dart';
import 'dart:async';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/DeleteConfirmationDialog.dart';
import 'LectureBar.dart';

class SubCategoriesBar extends StatefulWidget {
  final String selectedCategory;
  final bool isSidebarVisible;

  const SubCategoriesBar({
    Key? key,
    required this.selectedCategory,
    required this.isSidebarVisible,
  }) : super(key: key);

  @override
  _SubCategoriesBarState createState() => _SubCategoriesBarState();
}

class _SubCategoriesBarState extends State<SubCategoriesBar> with SingleTickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Subscribe to the stream first
    _categoriesStream = UnifiedDatabaseService().subjectsStream;

    // Then initialize data
    _initializeSelectedCategoryCode();
  }

  @override
  void didUpdateWidget(SubCategoriesBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the category has changed, we need to update the selected code
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      // Reset the selected code
      _selectedCategoryCode = null;

      // Check if we already have data loaded
      if (_categoryData != null &&
          _categoryData!['subCategories'] != null &&
          _categoryData!['subCategories'][widget.selectedCategory] != null) {

        final codes = _categoryData!['subCategories'][widget.selectedCategory] as List<dynamic>;
        if (codes.isNotEmpty) {
          _selectedCategoryCode = codes.first.toString();
          _controller.reset();
          _controller.forward();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeSelectedCategoryCode() async {
    try {
      final data = await UnifiedDatabaseService().fetchCategoriesAndSubCategories();

      setState(() {
        _categoryData = data;
        _isLoading = false;

        // Set the initial code for the selected category
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

          // Prepare list of codes for the selected category
          final codes = snapshot.data!['subCategories'][widget.selectedCategory] as List<dynamic>;

          // If we have data but no selected category, select the first one
          if (_selectedCategoryCode == null && codes.isNotEmpty) {
            _selectedCategoryCode = codes.first.toString();
            // Don't call setState here as it can cause rebuild loops
          }

          // If selected category no longer exists in the updated list
          if (_selectedCategoryCode != null && !codes.contains(_selectedCategoryCode)) {
            if (codes.isNotEmpty) {
              _selectedCategoryCode = codes.first.toString();
              // Don't call setState here as it can cause rebuild loops
            } else {
              _selectedCategoryCode = null;
            }
          }

          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: widget.isSidebarVisible ? 40.0 : 0.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: widget.isSidebarVisible
                    ? RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 16.0),
                          child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 100,
                    itemCount: codes.length,
                    itemBuilder: (context, index) {
                      final code = codes[index].toString();
                      final isSelected = _selectedCategoryCode == code;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_selectedCategoryCode != code) {
                                setState(() {
                                  _selectedCategoryCode = code;
                                });
                                _controller.reset();
                                _controller.forward();
                              }
                            },
                            onLongPress: () => DeleteConfirmationDialog.showDeleteSubCategory(
                              context: context,
                              category: widget.selectedCategory,
                              subCategory: code,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                                vertical: 12.0,
                              ),
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Text(
                                  code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (_selectedCategoryCode != null)
                Expanded(
                  child: RepaintBoundary(
                    child: FadeTransition(
                      opacity: _slideAnimation,
                      child: LectureBar(
                        selectedCategory: widget.selectedCategory,
                        selectedCategoryCode: _selectedCategoryCode!,
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