import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/sync_coordinator.dart';

void main() {
  test('does not overlap synchronization requests', () async {
    final gate = Completer<void>();
    var calls = 0;
    final coordinator = SyncCoordinator(onSync: () async {
      calls += 1;
      await gate.future;
    });

    final first = coordinator.trigger();
    await Future<void>.delayed(Duration.zero);
    await coordinator.trigger();

    expect(calls, 1);
    gate.complete();
    await first;
    coordinator.dispose();
  });

  test('pauses synchronization while the app is in background', () async {
    var calls = 0;
    final coordinator = SyncCoordinator(onSync: () async => calls += 1);

    coordinator.setForeground(false);
    await coordinator.trigger();

    expect(calls, 0);
    coordinator.dispose();
  });
}
