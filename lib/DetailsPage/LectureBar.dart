import 'package:flutter/material.dart';
import '../Utils/Code_data_fetch.dart';
import '../Utils/lecture_colors.dart';
import '../widgets/LectureDetailsModal.dart';

class LectureBar extends StatefulWidget {
  final String selectedSubject;
  final String selectedSubjectCode;

  LectureBar({
    required this.selectedSubject,
    required this.selectedSubjectCode,
  });

  @override
  _LectureBarState createState() => _LectureBarState();
}

class _LectureBarState extends State<LectureBar> {
  List<MapEntry<String, dynamic>> _filteredLectureData = [];

  @override
  void initState() {
    super.initState();
    _loadLectureData();
  }

  Future<void> _loadLectureData() async {
    final lectureData = await getStoredCodeData(widget.selectedSubject,widget.selectedSubjectCode);
    final filteredLectureData = lectureData.entries
        .where((entry) => !(entry.value['only_once'] == 1 && entry.value['status'] == 'Disabled'))
        .toList();

    setState(() {
      _filteredLectureData = filteredLectureData;
    });
  }

  void _showLectureDetails(BuildContext context, String lectureNo, dynamic details) {
    if (details is! Map<String, dynamic>) {
      details = Map<String, dynamic>.from(details);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return LectureDetailsModal(
          lectureNo: lectureNo,
          details: details,
          selectedSubject: widget.selectedSubject,
          selectedSubjectCode: widget.selectedSubjectCode,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = _calculateColumns(constraints.maxWidth);
          double aspectRatio = (constraints.maxWidth / crossAxisCount) / 150;

          return GridView.builder(
            padding: EdgeInsets.all(0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: _filteredLectureData.length,
            itemBuilder: (context, index) {
              final lectureNo = _filteredLectureData[index].key;
              final details = _filteredLectureData[index].value;

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showLectureDetails(context, lectureNo, details),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoChip(context, details['lecture_type']),
                            Text(
                              lectureNo,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildCompactInfoRow(
                                context,
                                'Learned:',
                                details['date_learnt'],
                                'Revised:',
                                details['date_revised'],
                              ),
                              _buildCompactInfoRow(
                                context,
                                'Revisions:',
                                details['no_revision'].toString(),
                                'Missed:',
                                details['missed_revision'].toString(),
                                isAlert: int.parse(details['missed_revision'].toString()) > 0,
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Scheduled: ${details['date_scheduled']}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String text) {
    return FutureBuilder<Color>(
      future: LectureColors.getLectureTypeColor(context, text),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey, // Placeholder color while loading
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red, // Error color
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: snapshot.data,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildCompactInfoRow(
      BuildContext context,
      String label1,
      String value1,
      String label2,
      String value2, {
        bool isAlert = false,
      }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    TextStyle? labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    TextStyle? valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(label1, style: labelStyle),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  value1,
                  style: valueStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(label2, style: labelStyle),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  value2,
                  style: valueStyle?.copyWith(
                    color: isAlert ? colorScheme.error : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _calculateColumns(double width) {
    if (width < 600) return 1;         // Mobile
    if (width < 900) return 2;         // Tablet
    if (width < 1200) return 3;        // Small desktop
    if (width < 1500) return 4;        // Medium desktop
    return 5;                          // Large desktop
  }
}