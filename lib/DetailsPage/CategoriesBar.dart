import 'package:flutter/material.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/DeleteConfirmationDialog.dart';
import 'CodeBar.dart';

class CategoriesBar extends StatefulWidget {
  @override
  _CategoriesBarState createState() => _CategoriesBarState();
}

class _CategoriesBarState extends State<CategoriesBar> with SingleTickerProviderStateMixin {
  String? _selectedCategory;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  // Stream subscription
  Stream<Map<String, dynamic>>? _categoriesStream;
  Map<String, dynamic>? _currentData;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Initialize with current data if available
    _initializeSelectedCategory();

    // Subscribe to the stream
    _categoriesStream = UnifiedDatabaseService().subjectsStream;

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeSelectedCategory() async {
    try {
      final data = await UnifiedDatabaseService().fetchCategoriesAndSubCategories();
      if (data['subjects'].isNotEmpty) {
        setState(() {
          _selectedCategory = data['subjects'].first;
          _currentData = data;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, dynamic>>(
        // Use the stream instead of future
        stream: _categoriesStream,
        initialData: _currentData,
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
          } else if (!snapshot.hasData || snapshot.data!['subjects'].isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No categories found',
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

          final subjects = snapshot.data!['subjects'];

          // If we have data but no selected category, select the first one
          if (_selectedCategory == null && subjects.isNotEmpty) {
            _selectedCategory = subjects.first;
          }

          // If selected category no longer exists in the updated list
          if (_selectedCategory != null && !subjects.contains(_selectedCategory)) {
            if (subjects.isNotEmpty) {
              _selectedCategory = subjects.first;
            } else {
              _selectedCategory = null;
            }
          }

          return Column(
            children: [
              if (_selectedCategory != null)
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: CodeBar(selectedCategory: _selectedCategory!),
                  ),
                ),
              Container(
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
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final category = subjects[index];
                      final isSelected = _selectedCategory == category;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                              });
                              _controller.reset();
                              _controller.forward();
                            },
                            onLongPress: () => DeleteConfirmationDialog.showDeleteCategory(
                              context: context,
                              category: category,
                            ),
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
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.book,
                                      size: 18,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimary
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight:
                                        isSelected ? FontWeight.w600 : FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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