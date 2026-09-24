import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) =>
      Card(child: ListTile(title: Text(title)));
}
