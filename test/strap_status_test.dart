import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ui2/strap_status.dart';

void main() {
  test('documents the low-battery threshold used by the UI', () {
    expect(StrapStatus.lowBatteryThresholdPct, 20);
  });

  test('charging takes precedence over a low battery warning', () {
    final status = StrapStatus.from(
      connection: 'connected',
      battery: 10,
      charging: true,
    );
    expect(status.kind, StrapStatusKind.charging);
  });

  test('low battery is actionable while not charging', () {
    final status = StrapStatus.from(
      connection: 'connected',
      battery: 20,
      charging: false,
    );
    expect(status.kind, StrapStatusKind.lowBattery);
  });

  test('connection state remains visible when battery is unknown', () {
    final status = StrapStatus.from(
      connection: 'disconnected',
      battery: null,
      charging: false,
    );
    expect(status.title, 'Band disconnected');
  });
}
