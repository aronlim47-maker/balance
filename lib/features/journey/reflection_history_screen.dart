import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/services/verified_progress_service.dart';
import '../../domain/models/reflection_record.dart';

class ReflectionHistoryScreen extends StatefulWidget {
  const ReflectionHistoryScreen({super.key});
  @override
  State<ReflectionHistoryScreen> createState() =>
      _ReflectionHistoryScreenState();
}

class _ReflectionHistoryScreenState extends State<ReflectionHistoryScreen> {
  late Future<List<ReflectionRecord>> _history;
  @override
  void initState() {
    super.initState();
    _history = _read();
  }

  Future<List<ReflectionRecord>> _read() =>
      context.read<VerifiedProgressService?>()?.fetchReflections() ??
      Future.value([]);
  Future<void> _reload() async {
    final history = _read();
    setState(() {
      _history = history;
    });
    // FutureBuilder displays the safe error message; refresh must also finish.
    try {
      await history;
    } catch (_) {
      /* handled by FutureBuilder */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My reflections')),
    body: FutureBuilder<List<ReflectionRecord>>(
      future: _history,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            if (snapshot.hasError) ...[
              Text(
                AppErrorMessage.from(
                  snapshot.error!,
                  fallback: 'Could not load reflections. Try again.',
                ),
              ),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ] else if (snapshot.connectionState == ConnectionState.done &&
                snapshot.data!.isEmpty)
              const Text('No reflections yet.'),
            if (!snapshot.hasError)
              for (final reflection in snapshot.data ?? <ReflectionRecord>[])
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.yMMMd().add_jm().format(
                            reflection.createdAt.toLocal(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(reflection.body),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
