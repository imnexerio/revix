import 'package:flutter/material.dart';

class LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const LegendItem({
    Key? key,
    required this.label,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 8,
          child: Icon(
            icon,
            color: Colors.white,
            size: 10,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}