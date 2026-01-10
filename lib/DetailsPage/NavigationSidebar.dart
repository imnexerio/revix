import 'package:flutter/material.dart';
import '../Utils/UnifiedDatabaseService.dart';
import '../Utils/DeleteConfirmationDialog.dart';
import 'EntryBar.dart';

class NavigationSidebar extends StatefulWidget {
  final bool isSidebarVisible;
  final String? parentSelection;

  const NavigationSidebar({
    Key? key,
    required this.isSidebarVisible,
    this.parentSelection,
  }) : super(key: key);

  @override
  _NavigationSidebarState createState() => _NavigationSidebarState();
}

class _NavigationSidebarState extends State<NavigationSidebar>
    with SingleTickerProviderStateMixin {
  String? _selectedItem;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Stream<Map<String, dynamic>>? _dataStream;
  Map<String, dynamic>? _currentData;

  /// Whether this is the top level (categories) or nested level (subcategories)
  bool get _isTopLevel => widget.parentSelection == null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _initializeSelectedItem();
    _dataStream = UnifiedDatabaseService().subjectsStream;
    _controller.forward();
  }

  @override
  void didUpdateWidget(NavigationSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If parent selection changed (only relevant for nested level)
    if (!_isTopLevel && oldWidget.parentSelection != widget.parentSelection) {
      _selectedItem = null;

      if (_currentData != null &&
          _currentData!['subCategories'] != null &&
          _currentData!['subCategories'][widget.parentSelection] != null) {
        final items = _currentData!['subCategories'][widget.parentSelection] as List<dynamic>;
        if (items.isNotEmpty) {
          _selectedItem = items.first.toString();
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

  Future<void> _initializeSelectedItem() async {
    try {
      final data = await UnifiedDatabaseService().fetchCategoriesAndSubCategories();
      final items = _extractItems(data);
      
      if (items.isNotEmpty) {
        setState(() {
          _selectedItem = items.first.toString();
          _currentData = data;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Extracts the list of items based on the level
  List<dynamic> _extractItems(Map<String, dynamic> data) {
    if (_isTopLevel) {
      return data['subjects'] ?? [];
    } else {
      final subCategories = data['subCategories'] ?? {};
      return subCategories[widget.parentSelection] ?? [];
    }
  }

  /// Returns the empty state message based on the level
  String get _emptyMessage {
    if (_isTopLevel) {
      return 'No categories found';
    } else {
      return 'No sub category found for ${widget.parentSelection}';
    }
  }

  /// Handles long press delete action based on level
  void _handleDelete(String item) {
    if (_isTopLevel) {
      DeleteConfirmationDialog.showDeleteCategory(
        context: context,
        category: item,
      );
    } else {
      DeleteConfirmationDialog.showDeleteSubCategory(
        context: context,
        category: widget.parentSelection!,
        subCategory: item,
      );
    }
  }

  /// Builds the child widget based on the level
  Widget _buildChild() {
    if (_isTopLevel) {
      // Categories level → show SubCategories (another NavigationSidebar)
      return NavigationSidebar(
        parentSelection: _selectedItem!,
        isSidebarVisible: widget.isSidebarVisible,
      );
    } else {
      // SubCategories level → show EntryBar
      return EntryBar(
        selectedCategory: widget.parentSelection!,
        selectedCategoryCode: _selectedItem!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _dataStream,
        initialData: _currentData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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
                  Icon(Icons.assignment_outlined,
                      size: 48, color: Colors.grey[400]),
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
          }

          final items = snapshot.hasData ? _extractItems(snapshot.data!) : [];

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _emptyMessage,
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

          // Update current data cache
          if (snapshot.hasData) {
            _currentData = snapshot.data;
          }

          // Auto-select first item if none selected
          if (_selectedItem == null && items.isNotEmpty) {
            _selectedItem = items.first.toString();
          }

          // If selected item no longer exists in the list
          if (_selectedItem != null && !items.contains(_selectedItem)) {
            if (items.isNotEmpty) {
              _selectedItem = items.first.toString();
            } else {
              _selectedItem = null;
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.0, vertical: 16.0),
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              scrollbars: false,
                            ),
                            child: ListView.builder(
                              scrollDirection: Axis.vertical,
                              physics: const BouncingScrollPhysics(),
                              cacheExtent: 100,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index].toString();
                                final isSelected = _selectedItem == item;

                                return Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (_selectedItem != item) {
                                          setState(() {
                                            _selectedItem = item;
                                          });
                                          _controller.reset();
                                          _controller.forward();
                                        }
                                      },
                                      onLongPress: () => _handleDelete(item),
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                          vertical: 12.0,
                                        ),
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: Text(
                                            item,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                              fontSize: 16,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
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
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (_selectedItem != null)
                Expanded(
                  child: RepaintBoundary(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildChild(),
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
