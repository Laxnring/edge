import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../fitness/rockport.dart';
import '../../fitness/rockport_history.dart';
import '../../state/app_state.dart';

/// Guided WHOOP-specific one-mile fitness estimate.
///
/// The phone supplies distance/time; WHOOP supplies the live finish HR. This
/// screen deliberately does not use Apple Health or pretend the strap itself
/// measured VO2 max.
class RockportTestScreen extends StatefulWidget {
  const RockportTestScreen({super.key});

  @override
  State<RockportTestScreen> createState() => _RockportTestScreenState();
}

class _RockportTestScreenState extends State<RockportTestScreen> {
  DateTime? _started;
  RockportResult? _result;
  List<RockportAttempt> _history = const [];
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _history = RockportHistory.read();
  }

  Future<void> _start(AppState app) async {
    if (app.activeWorkout != null) return;
    app.startWorkout(type: 'walking');
    setState(() {
      _started = DateTime.now();
      _result = null;
    });
  }

  Future<void> _finish(AppState app) async {
    final started = _started;
    final w = app.activeWorkout;
    if (started == null || w == null || _finishing) return;
    setState(() => _finishing = true);
    final distanceMeters = (app.liveDistanceKm ?? 0) * 1000;
    final elapsed = DateTime.now().difference(started);
    final finishHr = w.currentHr;
    final p = app.user ?? const <String, dynamic>{};
    final sex = switch ((p['sex']?.toString().toLowerCase() ?? '')) {
      'm' || 'male' => RockportSex.male,
      'f' || 'female' => RockportSex.female,
      _ => null,
    };
    final result = estimateRockport(
      RockportInput(
        ageYears: (p['age'] as num?)?.round(),
        weightKg: (p['weight_kg'] as num?)?.toDouble(),
        sex: sex,
        distanceMeters: distanceMeters,
        elapsed: elapsed,
        finishHeartRateBpm: finishHr != null && finishHr > 0 ? finishHr : null,
      ),
    );
    await app.stopWorkout();
    if (!mounted) return;
    if (result.isEstimated) {
      RockportHistory.add(
        RockportAttempt(
          at: DateTime.now(),
          vo2Max: result.vo2MaxMlKgMin!,
          distanceMeters: distanceMeters,
          durationSeconds: elapsed.inSeconds,
          finishHeartRate: finishHr!,
        ),
      );
    }
    setState(() {
      _result = result;
      _history = RockportHistory.read();
      _started = null;
      _finishing = false;
    });
  }

  String _reason(RockportRefusal? refusal) => switch (refusal) {
    RockportRefusal.profileIncomplete =>
      'Complete age and body mass in Profile first.',
    RockportRefusal.unsupportedEquationProfile =>
      'This test needs a supported Rockport equation profile.',
    RockportRefusal.distanceOutsideProtocol =>
      'The recorded distance was not one mile. Try again with GPS enabled.',
    RockportRefusal.durationOutsideProtocol =>
      'The elapsed time was outside the brisk-walk protocol.',
    RockportRefusal.finishHeartRateOutsideProtocol =>
      'WHOOP did not provide a valid finish heart rate.',
    null => 'The estimate is unavailable.',
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final running = _started != null && app.activeWorkout != null;
    final distance = app.liveDistanceKm;
    final hr = app.activeWorkout?.currentHr ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('WHOOP Fitness Test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Rockport one-mile walk',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Walk one mile briskly. Your phone records distance and time; '
            'WHOOP provides the finish heart rate. This is a field estimate, '
            'not a clinical measurement.',
          ),
          const SizedBox(height: 24),
          if (running) ...[
            Text(
              'Distance: ${distance?.toStringAsFixed(2) ?? '0.00'} km',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'WHOOP HR: ${hr > 0 ? '$hr bpm' : 'waiting…'}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _finishing ? null : () => _finish(app),
              icon: const Icon(Icons.flag),
              label: Text(_finishing ? 'Finishing…' : 'Finish test'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _start(app),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start one-mile test'),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _result!.isEstimated
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VO₂ max estimate',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_result!.vo2MaxMlKgMin!.toStringAsFixed(1)} '
                            'mL/kg/min',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'WHOOP HR + phone GPS · Rockport equation',
                          ),
                        ],
                      )
                    : Text(_reason(_result!.refusal)),
              ),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Previous tests',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (RockportHistory.initialBaseline(_history) case final baseline?)
              Text(
                'Initial personal baseline: ${baseline.toStringAsFixed(1)} mL/kg/min',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ..._history
                .take(5)
                .map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${a.vo2Max.toStringAsFixed(1)} mL/kg/min'),
                    subtitle: Text(
                      '${a.at.toLocal().toString().substring(0, 16)} · '
                      '${(a.durationSeconds / 60).toStringAsFixed(1)} min · ${a.finishHeartRate} bpm',
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
