import 'package:flutter/material.dart';

class RecoverySlotCard extends StatelessWidget {
  const RecoverySlotCard({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Card(child: ListTile(title: Text(label)));
}
