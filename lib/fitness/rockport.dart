/// Rockport one-mile walk-test estimator.
///
/// This is deliberately a *test result*, not a passive "WHOOP VO2 max".
/// The strap contributes the finish heart rate; phone GPS (or a measured
/// track) contributes distance and elapsed time.  The equation was published
/// for male/female cohorts, so an unrepresented profile is withheld rather
/// than silently assigning somebody to a coefficient.

library;

import 'dart:math' as math;

/// Distance prescribed by the Rockport one-mile walk test.
const double kRockportDistanceMeters = 1609.344;

/// GPS routes are allowed a small endpoint tolerance.  Larger errors mean the
/// walk was not the validated one-mile protocol, so no result is returned.
const double kRockportDistanceToleranceMeters = 40;

enum RockportSex { male, female }

enum RockportRefusal {
  profileIncomplete,
  unsupportedEquationProfile,
  distanceOutsideProtocol,
  durationOutsideProtocol,
  finishHeartRateOutsideProtocol,
}

/// Inputs captured at the end of a Rockport one-mile brisk walk.
class RockportInput {
  const RockportInput({
    required this.ageYears,
    required this.weightKg,
    required this.sex,
    required this.distanceMeters,
    required this.elapsed,
    required this.finishHeartRateBpm,
  });

  final int? ageYears;
  final double? weightKg;
  final RockportSex? sex;
  final double distanceMeters;
  final Duration elapsed;
  final int? finishHeartRateBpm;
}

/// A result in the standard ml/kg/min unit, or a precise reason to withhold
/// one.  The caller must keep the provenance label: "WHOOP HR + GPS".
class RockportResult {
  const RockportResult._({this.vo2MaxMlKgMin, this.refusal});

  factory RockportResult.estimated(double value) =>
      RockportResult._(vo2MaxMlKgMin: value);

  factory RockportResult.withheld(RockportRefusal reason) =>
      RockportResult._(refusal: reason);

  final double? vo2MaxMlKgMin;
  final RockportRefusal? refusal;

  bool get isEstimated => vo2MaxMlKgMin != null;
}

/// Applies the original Rockport regression:
///
/// `132.853 - .0769*weight(lb) - .3877*age + 6.315*male
///  - 3.2649*time(min) - .1565*finishHR`.
///
/// A result is withheld if the source data does not describe the prescribed
/// test. It is a field-test estimate for fitness use, not a clinical VO2-max
/// measurement.
RockportResult estimateRockport(RockportInput input) {
  final age = input.ageYears;
  final weightKg = input.weightKg;
  if (age == null || age <= 0 || weightKg == null || weightKg <= 0) {
    return RockportResult.withheld(RockportRefusal.profileIncomplete);
  }
  final sex = input.sex;
  if (sex == null) {
    return RockportResult.withheld(RockportRefusal.unsupportedEquationProfile);
  }
  if ((input.distanceMeters - kRockportDistanceMeters).abs() >
      kRockportDistanceToleranceMeters) {
    return RockportResult.withheld(RockportRefusal.distanceOutsideProtocol);
  }
  final minutes = input.elapsed.inMilliseconds / Duration.millisecondsPerMinute;
  // A brisk one-mile walk outside this range is most likely a paused route,
  // bad GPS endpoint, or a session that was not the intended protocol.
  if (minutes < 8 || minutes > 30) {
    return RockportResult.withheld(RockportRefusal.durationOutsideProtocol);
  }
  final hr = input.finishHeartRateBpm;
  if (hr == null || hr < 50 || hr > 220) {
    return RockportResult.withheld(
      RockportRefusal.finishHeartRateOutsideProtocol,
    );
  }

  final male = sex == RockportSex.male ? 1 : 0;
  final value =
      132.853 -
      (0.0769 * weightKg * 2.2046226218) -
      (0.3877 * age) +
      (6.315 * male) -
      (3.2649 * minutes) -
      (0.1565 * hr);
  // The regression can extrapolate below zero for invalid combinations even
  // after the protocol gates. Do not turn that into a plausible-looking value.
  if (!value.isFinite || value <= 0) {
    return RockportResult.withheld(RockportRefusal.profileIncomplete);
  }
  return RockportResult.estimated(math.max(0, value));
}
