import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/ui2/live_hr_window.dart';

void main() {
  test('selects by timestamps rather than sample count', () {
    final now = DateTime.fromMillisecondsSinceEpoch(100000);
    final samples = <({int at, int hr})>[
      (at: 100000 - 15 * 60 * 1000, hr: 60),
      (at: 100000 - 10 * 60 * 1000, hr: 62),
      (at: 100000 - 1000, hr: 64),
      (at: 100001, hr: 80),
    ];
    expect(
      selectLiveHrWindow(
        samples,
        now: now,
        window: const Duration(minutes: 15),
      ),
      [60, 62, 64],
    );
  });
}
