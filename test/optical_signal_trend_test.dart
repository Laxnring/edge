import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/fitness/optical_signal_trend.dart';

void main() {
  test('optical trend is unavailable without enough data', () {
    expect(OpticalSignalTrend.compare(
      earlierMean: 100, earlierCount: 29, recentMean: 110, recentCount: 30,
    ).direction, OpticalSignalDirection.unavailable);
  });

  test('optical trend gives a stable direction only beyond its deadband', () {
    expect(OpticalSignalTrend.compare(
      earlierMean: 100, earlierCount: 30, recentMean: 107, recentCount: 30,
    ).arrow, '↑');
    expect(OpticalSignalTrend.compare(
      earlierMean: 100, earlierCount: 30, recentMean: 96, recentCount: 30,
    ).arrow, '→');
    expect(OpticalSignalTrend.compare(
      earlierMean: 100, earlierCount: 30, recentMean: 93, recentCount: 30,
    ).arrow, '↓');
  });
}
