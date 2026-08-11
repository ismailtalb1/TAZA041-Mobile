import 'dart:async';

/// Runs a single adaptive synchronization loop and never overlaps requests.
class SyncCoordinator {
  SyncCoordinator({
    required this.onSync,
    this.interval = const Duration(seconds: 4),
  });

  final Future<void> Function() onSync;
  final Duration interval;

  Timer? _timer;
  bool _isRunning = false;
  bool _isForeground = true;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => trigger());
  }

  void setForeground(bool value) {
    _isForeground = value;
    if (value) trigger();
  }

  Future<void> trigger() async {
    if (!_isForeground || _isRunning) return;
    _isRunning = true;
    try {
      await onSync();
    } finally {
      _isRunning = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
