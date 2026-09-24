import 'package:flutter/material.dart';

class WorldStatusCard extends StatelessWidget {
  const WorldStatusCard({super.key});
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(padding: EdgeInsets.all(16), child: Text('当前状态')),
  );
}
