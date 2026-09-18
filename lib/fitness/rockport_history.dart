import 'dart:convert';

import '../state/prefs.dart';

/// Small local history for the guided Rockport test. This is intentionally
/// separate from strap samples: it records provenance and lets the user see
/// whether a repeat test is moving in the same direction.
class RockportAttempt {
  const RockportAttempt({
    required this.at,
    required this.vo2Max,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.finishHeartRate,
  });

  final DateTime at;
  final double vo2Max;
  final double distanceMeters;
  final int durationSeconds;
  final int finishHeartRate;

  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'vo2': vo2Max,
    'distance_m': distanceMeters,
    'duration_s': durationSeconds,
    'finish_hr': finishHeartRate,
  };

  static RockportAttempt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse(raw['at']?.toString() ?? '');
    final vo2 = (raw['vo2'] as num?)?.toDouble();
    final distance = (raw['distance_m'] as num?)?.toDouble();
    final duration = (raw['duration_s'] as num?)?.round();
    final hr = (raw['finish_hr'] as num?)?.round();
    if (at == null ||
        vo2 == null ||
        distance == null ||
        duration == null ||
        hr == null) {
      return null;
    }
    return RockportAttempt(
      at: at,
      vo2Max: vo2,
      distanceMeters: distance,
      durationSeconds: duration,
      finishHeartRate: hr,
    );
  }
}

class RockportHistory {
  RockportHistory._();

  static const key = 'fitness.rockport.history';
  static const maxEntries = 12;

  /// Withhold a personal baseline until two valid walks exist, then use their
  /// median (the midpoint of the two values) rather than one noisy test.
  static double? initialBaseline(List<RockportAttempt> entries) {
    if (entries.length < 2) return null;
    final values = entries.take(2).map((e) => e.vo2Max).toList()..sort();
    return (values[0] + values[1]) / 2;
  }

  static List<RockportAttempt> read() {
    final raw = Prefs.getString(key, '');
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(RockportAttempt.fromJson)
          .whereType<RockportAttempt>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static void add(RockportAttempt attempt) {
    final entries = [
      attempt,
      ...read(),
    ].take(maxEntries).map((e) => e.toJson()).toList();
    Prefs.setString(key, jsonEncode(entries));
  }
}
