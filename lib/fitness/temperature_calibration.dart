/// Honest calibration state for the strap's relative skin-temperature signal.
///
/// The WHOOP 4 thermistor value is not an absolute core-temperature reading.
/// It becomes useful only as a personal, overnight baseline.  Keep this policy
/// in one pure helper so UI and exports can explain exactly what calibration
/// means without inventing °C or fever thresholds.
enum TemperatureCalibrationPhase { collecting, preliminary, established }

class TemperatureCalibration {
  static const int minimumNights = 3;
  static const int preliminaryNights = 7;
  static const int establishedNights = 14;

  static TemperatureCalibrationPhase phaseFor(int nights) {
    if (nights < preliminaryNights) {
      return TemperatureCalibrationPhase.collecting;
    }
    if (nights < establishedNights) {
      return TemperatureCalibrationPhase.preliminary;
    }
    return TemperatureCalibrationPhase.established;
  }

  static int nightsRemaining(int nights) {
    final target = phaseFor(nights) == TemperatureCalibrationPhase.preliminary
        ? establishedNights
        : preliminaryNights;
    return (target - nights).clamp(0, target);
  }

  static String label(int nights) {
    switch (phaseFor(nights)) {
      case TemperatureCalibrationPhase.collecting:
        return 'Calibrating: ${nightsRemaining(nights)} more nights needed';
      case TemperatureCalibrationPhase.preliminary:
        return 'Preliminary baseline: ${nightsRemaining(nights)} more nights to mature';
      case TemperatureCalibrationPhase.established:
        return 'Established personal baseline';
    }
  }
}
