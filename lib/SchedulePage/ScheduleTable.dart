 import 'package:flutter/material.dart';
 import 'RevisionGraph.dart'; // Import the RevisionGraph widget

 class ScheduleTable extends StatelessWidget {
   final List<Map<String, dynamic>> records;
   final String title;
   final Function(BuildContext, Map<String, dynamic>) onSelect;

   const ScheduleTable({
     Key? key,
     required this.records,
     required this.title,
     required this.onSelect,
   }) : super(key: key);

   @override
   Widget build(BuildContext context) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Padding(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(
                 title,
                 style: const TextStyle(
                   fontSize: 20,
                   fontWeight: FontWeight.bold,
                 ),
               ),
               _buildFilterButton(context),
             ],
           ),
         ),
         const SizedBox(height: 8),
         // Responsive grid of cards
         GridView.builder(
           shrinkWrap: true,
           physics: const NeverScrollableScrollPhysics(),
           padding: const EdgeInsets.symmetric(horizontal: 12),
           gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
             maxCrossAxisExtent: 400, // Maximum width of each card
             childAspectRatio: MediaQuery.of(context).size.width > 600 ? 3 : 2,
             crossAxisSpacing: 8,
             mainAxisSpacing: 8,
             mainAxisExtent: 130, // Fixed height for each card
           ),
           itemCount: records.length,
           itemBuilder: (context, index) {
             final record = records[index];
             final bool isCompleted = record['date_learnt'] != null &&
                 record['date_learnt'].toString().isNotEmpty;
             // print(record);

             return _buildClassCard(context, record, isCompleted);
           },
         ),
       ],
     );
   }

   Widget _buildFilterButton(BuildContext context) {
     return OutlinedButton.icon(
       style: OutlinedButton.styleFrom(
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12),
         ),
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
       ),
       icon: const Icon(Icons.filter_list, size: 16),
       label: const Text('Filter'),
       onPressed: () {
         // Show filter options
         showModalBottomSheet(
           context: context,
           shape: const RoundedRectangleBorder(
             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
           ),
           builder: (context) => _buildFilterSheet(context),
         );
       },
     );
   }

   Widget _buildFilterSheet(BuildContext context) {
     final List<String> subjects = records
         .map((record) => record['subject'] as String)
         .toSet()
         .toList();

     return Padding(
       padding: const EdgeInsets.all(20.0),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           const Text(
             'Filter Classes',
             style: TextStyle(
               fontWeight: FontWeight.bold,
               fontSize: 18,
             ),
           ),
           const SizedBox(height: 16),
           const Text(
             'Subject',
             style: TextStyle(
               fontWeight: FontWeight.w600,
               fontSize: 15,
             ),
           ),
           const SizedBox(height: 8),
           Wrap(
             spacing: 8,
             children: subjects.map((subject) {
               return FilterChip(
                 label: Text(subject),
                 selected: false, // You can implement state management here
                 onSelected: (selected) {
                   // Filter functionality
                 },
               );
             }).toList(),
           ),
           const SizedBox(height: 16),
           const Text(
             'Status',
             style: TextStyle(
               fontWeight: FontWeight.w600,
               fontSize: 15,
             ),
           ),
           const SizedBox(height: 20),
           Row(
             mainAxisAlignment: MainAxisAlignment.end,
             children: [
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Reset'),
               ),
               const SizedBox(width: 12),
               ElevatedButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Apply'),
               ),
             ],
           ),
         ],
       ),
     );
   }

   Widget _buildClassCard(BuildContext context, Map<String, dynamic> record, bool isCompleted) {
     Color statusColor = isCompleted ? Colors.green.shade100 : Colors.orange.shade100;
     Color statusTextColor = isCompleted ? Colors.green.shade800 : Colors.orange.shade800;

     return Card(
       elevation: 0,
       margin: const EdgeInsets.all(4),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
         side: BorderSide(
           color: Theme.of(context).dividerColor.withOpacity(0.1),
           width: 1,
         ),
       ),
       child: InkWell(
         borderRadius: BorderRadius.circular(12),
         onTap: () => onSelect(context, record),
         child: Padding(
           padding: const EdgeInsets.all(12.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           record['subject'],
                           style: const TextStyle(
                             fontWeight: FontWeight.bold,
                             fontSize: 16,
                           ),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                         const SizedBox(height: 4),
                         Text(
                           '${record['lecture_type']} ${record['lecture_no']} · ${record['subject_code']}',
                           style: TextStyle(
                             color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                             fontSize: 13,
                           ),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                         ),
                       ],
                     ),
                   ),
                   // Wrap RevisionGraph with SizedBox to provide bounded size
                   SizedBox(
                     width: 100, // Set appropriate width
                     height: 50, // Set appropriate height
                     child: CircularTimelineChart   (
                       dateLearnt:record['date_learnt'],
                       datesMissedRevisions: List<String>.from(record['dates_missed_revisions'] ?? []),
                       datesRevised: List<String>.from(record['dates_revised'] ?? []),
                     ),
                   ),
                 ],
               ),
               const Spacer(),
               Wrap(
                 spacing: 16,
                 runSpacing: 8,
                 children: [
                   _buildDateInfo(
                     context,
                     'Scheduled',
                     record['date_scheduled'] ?? '',
                     Icons.calendar_today,
                   ),
                   if (isCompleted)
                     _buildDateInfo(
                       context,
                       'Completed',
                       record['date_learnt'] ?? '',
                       Icons.check_circle_outline,
                     ),
                 ],
               ),
             ],
           ),
         ),
       ),
     );
   }

   Widget _buildDateInfo(BuildContext context, String label, String date, IconData icon) {
     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(
           icon,
           size: 14,
           color: Theme.of(context).colorScheme.primary,
         ),
         const SizedBox(width: 4),
         Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           mainAxisSize: MainAxisSize.min,
           children: [
             Text(
               label,
               style: TextStyle(
                 fontSize: 11,
                 color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
               ),
             ),
             Text(
               date,
               style: const TextStyle(
                 fontWeight: FontWeight.w500,
                 fontSize: 13,
               ),
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
           ],
         ),
       ],
     );
   }
 }