import 'package:flutter/material.dart';

class CapacityGapCard extends StatelessWidget {
  const CapacityGapCard({super.key, required this.overloadMinutes});
  final int overloadMinutes;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('超载：$overloadMinutes 分钟'),
    ),
  );
}
