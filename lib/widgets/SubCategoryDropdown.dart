import 'package:flutter/material.dart';

class SubCategoryDropdown extends StatelessWidget {
  final Map<String, List<String>> subCategories;
  final String selectedCategory;
  final String selectedCategoryCode;
  final ValueChanged<String?> onChanged;

  const SubCategoryDropdown({
    required this.subCategories,
    required this.selectedCategory,
    required this.selectedCategoryCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Select Sub Category',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        value: selectedCategoryCode.isEmpty ? null : selectedCategoryCode,
        onChanged: onChanged,
        items: selectedCategory.isEmpty
            ? []
            : [
                ...subCategories[selectedCategory]!.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                const DropdownMenuItem<String>(
                  value: 'Others',
                  child: Text('Others'),
                ),
              ],
        validator: (value) => value == null ? 'Please select a Sub Category' : null,
      ),
    );
  }
}