import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ui2/sync_health.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(100000);

  test('unknown or older-than-30-second BLE activity is stale', () {
    expect(isBleStale(null, now: now), isTrue);
    expect(
      isBleStale(now.subtract(const Duration(seconds: 31)), now: now),
      isTrue,
    );
  });

  test('activity at the 30-second boundary is still fresh', () {
    expect(
      isBleStale(now.subtract(const Duration(seconds: 30)), now: now),
      isFalse,
    );
  });
}
