import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/fitness/rockport.dart';

void main() {
  RockportInput valid({
    RockportSex sex = RockportSex.male,
    double distanceMeters = kRockportDistanceMeters,
    Duration elapsed = const Duration(minutes: 12, seconds: 15),
    int finishHr = 165,
  }) => RockportInput(
    ageYears: 30,
    weightKg: 180 / 2.2046226218,
    sex: sex,
    distanceMeters: distanceMeters,
    elapsed: elapsed,
    finishHeartRateBpm: finishHr,
  );

  test('implements the published Rockport regression in ml/kg/min', () {
    final result = estimateRockport(valid());
    // Published worked example: 30-year-old, male, 180 lb, 12:15, HR 165.
    expect(result.isEstimated, isTrue);
    expect(result.vo2MaxMlKgMin, closeTo(47.88, 0.02));
  });

  test('uses the female coefficient rather than silently treating as male', () {
    final male = estimateRockport(valid());
    final female = estimateRockport(valid(sex: RockportSex.female));
    expect(male.vo2MaxMlKgMin! - female.vo2MaxMlKgMin!, closeTo(6.315, 1e-9));
  });

  test('withholds when GPS did not produce a one-mile protocol', () {
    final result = estimateRockport(valid(distanceMeters: 1450));
    expect(result.isEstimated, isFalse);
    expect(result.refusal, RockportRefusal.distanceOutsideProtocol);
  });

  test('withholds when the live WHOOP finish HR is absent', () {
    final input = valid();
    final result = estimateRockport(
      RockportInput(
        ageYears: input.ageYears,
        weightKg: input.weightKg,
        sex: input.sex,
        distanceMeters: input.distanceMeters,
        elapsed: input.elapsed,
        finishHeartRateBpm: null,
      ),
    );
    expect(result.refusal, RockportRefusal.finishHeartRateOutsideProtocol);
  });
}
