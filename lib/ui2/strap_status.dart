enum StrapStatusKind { unknown, charging, lowBattery, connected, disconnected }

class StrapStatus {
  static const int lowBatteryThresholdPct = 20;

  const StrapStatus(this.kind, this.title);
  final StrapStatusKind kind;
  final String title;

  static StrapStatus from({
    required String connection,
    required int? battery,
    required bool charging,
  }) {
    if (charging) {
      return const StrapStatus(StrapStatusKind.charging, 'Band is charging');
    }
    if (battery != null && battery <= lowBatteryThresholdPct) {
      return const StrapStatus(
        StrapStatusKind.lowBattery,
        'Charge your band soon',
      );
    }
    if (connection == 'connected') {
      return const StrapStatus(StrapStatusKind.connected, 'Band connected');
    }
    if (connection.isNotEmpty) {
      return StrapStatus(StrapStatusKind.disconnected, 'Band $connection');
    }
    return const StrapStatus(
      StrapStatusKind.unknown,
      'Band status unavailable',
    );
  }
}
