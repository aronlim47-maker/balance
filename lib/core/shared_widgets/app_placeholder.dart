import 'package:flutter/material.dart';

import 'balance_scaffold.dart';

class AppPlaceholder extends StatelessWidget {
  const AppPlaceholder({super.key, required this.title, this.navigationIndex});
  final String title;
  final int? navigationIndex;

  @override
  Widget build(BuildContext context) {
    final content = Center(child: Text('$title is coming soon.'));
    if (navigationIndex == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: content,
      );
    }
    return BalanceScaffold(
      title: title,
      currentIndex: navigationIndex!,
      body: content,
    );
  }
}
