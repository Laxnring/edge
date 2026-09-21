/// Direction of the WHOOP 4 optical channels over adjacent windows.
///
/// This is intentionally *not* a blood-oxygen result. WHOOP 4's red/IR values
/// are not independently calibrated wavelengths, so this can only describe
/// whether the raw optical signal moved, never whether SpO₂ moved.
enum OpticalSignalDirection { up, down, steady, unavailable }

class OpticalSignalTrend {
  final OpticalSignalDirection direction;
  final double? change;

  const OpticalSignalTrend(this.direction, {this.change});

  static const unavailable = OpticalSignalTrend(OpticalSignalDirection.unavailable);

  String get arrow => switch (direction) {
        OpticalSignalDirection.up => '↑',
        OpticalSignalDirection.down => '↓',
        OpticalSignalDirection.steady => '→',
        OpticalSignalDirection.unavailable => '—',
      };

  /// Two averages from adjacent three-hour windows. Five percent is a display
  /// deadband, so small raw drift cannot make the arrow flicker.
  static OpticalSignalTrend compare({
    required double? earlierMean,
    required int earlierCount,
    required double? recentMean,
    required int recentCount,
  }) {
    if (earlierMean == null || recentMean == null ||
        earlierMean <= 0 || recentMean <= 0 ||
        earlierCount < 30 || recentCount < 30) return unavailable;
    final change = (recentMean - earlierMean) / earlierMean;
    return OpticalSignalTrend(
      change > .05
          ? OpticalSignalDirection.up
          : change < -.05
              ? OpticalSignalDirection.down
              : OpticalSignalDirection.steady,
      change: change,
    );
  }
}
