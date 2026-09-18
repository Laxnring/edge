import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/fitness/temperature_calibration.dart';

void main() {
  test('requires a short personal history before showing a trend', () {
    expect(
      TemperatureCalibration.phaseFor(0),
      TemperatureCalibrationPhase.collecting,
    );
    expect(
      TemperatureCalibration.phaseFor(6),
      TemperatureCalibrationPhase.collecting,
    );
    expect(TemperatureCalibration.nightsRemaining(6), 1);
  });

  test('marks 7-13 nights as preliminary, not clinical', () {
    expect(
      TemperatureCalibration.phaseFor(7),
      TemperatureCalibrationPhase.preliminary,
    );
    expect(TemperatureCalibration.nightsRemaining(7), 7);
  });

  test('marks 14 nights as an established personal baseline', () {
    expect(
      TemperatureCalibration.phaseFor(14),
      TemperatureCalibrationPhase.established,
    );
    expect(TemperatureCalibration.nightsRemaining(30), 0);
  });
}
