// A small, deliberately honest data-collection tool for testing whether the
// WHOOP 4 optical and temperature-like channels contain a usable personal
// signal. This is not an SpO2 or temperature display: it records the raw
// channels alongside optional reference-oximeter markers for later analysis.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart';
import '../../state/app_state.dart';
import '../ui2.dart';

const _kCaptureSessions = 'optical_capture.sessions.v1';

class _Marker {
  final int atMs;
  final double? referenceSpo2;

  const _Marker(this.atMs, {this.referenceSpo2});

  Map<String, dynamic> toJson() => {'at_ms': atMs, 'spo2': referenceSpo2};

  factory _Marker.fromJson(Map<String, dynamic> json) => _Marker(
    (json['at_ms'] as num).toInt(),
    referenceSpo2: (json['spo2'] as num?)?.toDouble(),
  );
}

class _Capture {
  final int startedAtMs;
  final int? endedAtMs;
  final List<_Marker> markers;

  const _Capture(this.startedAtMs, {this.endedAtMs, this.markers = const []});

  bool get active => endedAtMs == null;
  int get endMs => endedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  _Capture copyWith({int? endedAtMs, List<_Marker>? markers}) => _Capture(
    startedAtMs,
    endedAtMs: endedAtMs ?? this.endedAtMs,
    markers: markers ?? this.markers,
  );

  Map<String, dynamic> toJson() => {
    'started_at_ms': startedAtMs,
    'ended_at_ms': endedAtMs,
    'markers': [for (final marker in markers) marker.toJson()],
  };

  factory _Capture.fromJson(Map<String, dynamic> json) => _Capture(
    (json['started_at_ms'] as num).toInt(),
    endedAtMs: (json['ended_at_ms'] as num?)?.toInt(),
    markers: [
      for (final raw in (json['markers'] as List? ?? const []))
        if (raw is Map) _Marker.fromJson(raw.cast<String, dynamic>()),
    ],
  );
}

class OpticalCaptureScreen extends StatefulWidget {
  const OpticalCaptureScreen({super.key});

  @override
  State<OpticalCaptureScreen> createState() => _OpticalCaptureScreenState();
}

class _OpticalCaptureScreenState extends State<OpticalCaptureScreen> {
  List<_Capture> _sessions = const [];
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];
  Timer? _poll;

  _Capture? get _current {
    for (final session in _sessions) {
      if (session.active) return session;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _readRows());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw =
          jsonDecode(prefs.getString(_kCaptureSessions) ?? '[]') as List;
      _sessions = [
        for (final value in raw)
          if (value is Map) _Capture.fromJson(value.cast<String, dynamic>()),
      ];
    } catch (_) {
      _sessions = const [];
    }
    if (mounted) setState(() => _loading = false);
    await _readRows();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCaptureSessions,
      jsonEncode([for (final s in _sessions) s.toJson()]),
    );
  }

  Future<void> _readRows() async {
    final capture = _current ?? (_sessions.isEmpty ? null : _sessions.first);
    if (capture == null) return;
    try {
      final rows = await LocalDb.decodedOneHzBatchByRecTsRange(
        limit: 3600,
        fromRecTs: capture.startedAtMs ~/ 1000,
        toRecTs: capture.endMs ~/ 1000,
      );
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      // A sync may briefly hold the web database open. The next polling pass
      // will retry; the capture boundaries themselves are already saved.
    }
  }

  Future<void> _start() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() => _sessions = [_Capture(now), ..._sessions]);
    await _save();
    unawaited(context.read<AppState>().syncNow());
    await _readRows();
  }

  Future<void> _finish() async {
    final capture = _current;
    if (capture == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _sessions = [
        for (final session in _sessions)
          identical(session, capture)
              ? session.copyWith(endedAtMs: now)
              : session,
      ];
    });
    await _save();
    await _readRows();
  }

  Future<void> _markReference() async {
    final capture = _current;
    if (capture == null) return;
    final controller = TextEditingController();
    // null is Cancel; the empty string deliberately means "mark time only".
    final result = await showDialog<String?>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Reference oximeter reading'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'SpO₂ % (optional)',
            hintText: 'e.g. 98',
            helperText: 'Use a stable reading from a fingertip oximeter.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, ''),
            child: const Text('Mark time only'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed < 70 || parsed > 100) return;
              Navigator.pop(dialog, parsed.toString());
            },
            child: const Text('Save marker'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final value = result.isEmpty ? null : double.tryParse(result);
    final marker = _Marker(
      DateTime.now().millisecondsSinceEpoch,
      referenceSpo2: value,
    );
    setState(() {
      _sessions = [
        for (final session in _sessions)
          identical(session, capture)
              ? session.copyWith(markers: [...session.markers, marker])
              : session,
      ];
    });
    await _save();
  }

  String _csv(_Capture capture) {
    final bySecond = <int, List<_Marker>>{};
    for (final marker in capture.markers) {
      (bySecond[marker.atMs ~/ 1000] ??= []).add(marker);
    }
    final lines = <String>[
      'timestamp,heart_rate_bpm,red_raw,ir_raw,temp_raw,accel_g,reference_spo2',
    ];
    for (final row in _rows) {
      final ts = (row['rec_ts'] as num?)?.toInt();
      if (ts == null) continue;
      final ax = (row['ax'] as num?)?.toDouble();
      final ay = (row['ay'] as num?)?.toDouble();
      final az = (row['az'] as num?)?.toDouble();
      final motion = ax == null || ay == null || az == null
          ? ''
          : math.sqrt(ax * ax + ay * ay + az * az).toStringAsFixed(4);
      final refs = bySecond[ts] ?? const <_Marker>[];
      final reference = refs.isEmpty
          ? ''
          : refs.map((m) => m.referenceSpo2?.toString() ?? 'marked').join('|');
      lines.add(
        [
          DateTime.fromMillisecondsSinceEpoch(ts * 1000).toIso8601String(),
          row['hr'] ?? '',
          row['spo2_red_raw'] ?? '',
          row['spo2_ir_raw'] ?? '',
          row['skin_temp_raw'] ?? '',
          motion,
          reference,
        ].join(','),
      );
    }
    return lines.join('\n');
  }

  Future<void> _copy() async {
    final capture = _current ?? (_sessions.isEmpty ? null : _sessions.first);
    if (capture == null || _rows.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _csv(capture)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_rows.length} rows copied as CSV.')),
      );
    }
  }

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final capture = _current ?? (_sessions.isEmpty ? null : _sessions.first);
    return Scaffold(
      appBar: AppBar(title: const Text('Optical capture')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Research tool — not a blood-oxygen or temperature reading.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'It bookmarks WHOOP’s red/IR optical bytes and its temperature-like raw channel alongside motion, HR and optional reference-oximeter readings. Copy the CSV within three days; this raw substrate is intentionally short-lived.',
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.isConnected
                              ? 'Band connected'
                              : 'Band not connected',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.isConnected
                              ? 'Starting a capture requests a sync. Keep this tab open while the strap transfers its recording history.'
                              : 'Reconnect the band before starting a capture.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (capture == null)
                  FilledButton.icon(
                    onPressed: app.isConnected ? _start : null,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Start optical capture'),
                  )
                else ...[
                  Text(
                    capture.active
                        ? 'Capturing since ${_time(capture.startedAtMs)}'
                        : 'Latest capture: ${_time(capture.startedAtMs)}–${_time(capture.endMs)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${_rows.length} matching WHOOP records received'),
                  if (capture.active) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _markReference,
                      icon: const Icon(Icons.bookmarkAddOutlined),
                      label: const Text('Mark reference reading'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _finish,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Finish capture'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _rows.isEmpty ? null : _copy,
                    icon: const Icon(Icons.content_copy_outlined),
                    label: const Text('Copy captured rows as CSV'),
                  ),
                  if (capture.markers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Reference markers',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final marker in capture.markers)
                      Text(
                        '${_time(marker.atMs)} · ${marker.referenceSpo2 == null ? 'time marked' : '${marker.referenceSpo2}%'}',
                      ),
                  ],
                ],
                const SizedBox(height: 24),
                const Text(
                  'Temperature note',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'For WHOOP 4 this is a raw, device-specific signal, not an absolute body or core temperature. The useful first question is whether it is stable at rest and changes consistently from your own overnight baseline. Do not use it for fever decisions.',
                ),
              ],
            ),
    );
  }
}
