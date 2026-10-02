import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that remembers whether it has been disposed.
///
/// View models check [isDisposed] after awaiting async work so they do not
/// update state or notify listeners once their screen has closed.
abstract class LifecycleNotifier extends ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

