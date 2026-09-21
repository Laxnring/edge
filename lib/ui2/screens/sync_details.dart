import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../sync_health.dart';

/// Honest, inspectable sync state. The BLE layer does not expose a reliable
/// percentage because the strap can stream live and historical records on the
/// same connection, so this screen reports observable milestones instead.
class SyncDetailsScreen extends StatelessWidget {
  const SyncDetailsScreen({super.key});

  /// The one sentence a person needs before the diagnostic timeline below.
  ///
  /// `connected` and `syncingNow` answer different questions: the former only
  /// means GATT is open; the latter means records have actually reached local
  /// storage. Keeping those states separate is what prevents a stalled Chrome
  /// GATT session from looking like a slow first sync.
  _SyncExplanation _explain({
    required AppState app,
    required bool connected,
    required bool receiving,
    required bool deriving,
    required bool pending,
    required bool bleStale,
  }) {
    final status = app.engine.bandStatus;
    final connection = app.device.connection;
    if (status.isFault) {
      return _SyncExplanation(
        title: status.title,
        body: status.reason,
        next: status.fix ?? 'Reconnect the band, then try Sync now again.',
        icon: LucideIcons.triangleAlert,
        working: false,
      );
    }
    if (!connected) {
      final connecting = connection == 'connecting' || app.busy;
      return _SyncExplanation(
        title: connecting ? 'Connecting to your WHOOP' : 'Not syncing — band disconnected',
        body: connecting
            ? 'Chrome is opening the Bluetooth connection. No recording has reached Edge yet.'
            : 'A paired band is not an active connection. Edge cannot download data until the Bluetooth link is live.',
        next: connecting
            ? 'Keep this tab open and keep the band close.'
            : 'Tap Sync now. If Chrome does not show a chooser, use the Chrome window opened by RUN_EDGE.bat.',
        icon: connecting ? LucideIcons.bluetoothSearching : LucideIcons.bluetoothOff,
        working: connecting,
      );
    }
    if (bleStale) {
      return const _SyncExplanation(
        title: 'Connected, but no data is arriving',
        body: 'The Bluetooth link is open but has stopped delivering notifications. This is a stalled connection, not a slow sync.',
        next: 'Tap Sync now to reconnect. Keep the official WHOOP app fully closed while testing.',
        icon: LucideIcons.wifiOff,
        working: false,
      );
    }
    if (receiving) {
      return const _SyncExplanation(
        title: 'Downloading recordings from the band',
        body: 'Records are reaching local storage now. A large backlog can take several minutes.',
        next: 'Leave this screen open; Edge will start calculating automatically once the band goes quiet.',
        icon: LucideIcons.download,
        working: true,
      );
    }
    if (deriving || pending) {
      return _SyncExplanation(
        title: deriving ? 'Calculating today\'s health data' : 'Data received — calculation queued',
        body: deriving
            ? 'Edge is deriving sleep, recovery, strain and trends from the recordings already downloaded.'
            : 'The band data is stored. The calculation will start after the brief settling window.',
        next: 'Nothing to do — the dashboard refreshes when this step finishes.',
        icon: LucideIcons.chartNoAxesCombined,
        working: true,
      );
    }
    if (app.lastRecordAt == null) {
      return const _SyncExplanation(
        title: 'Connected — waiting for the first recording',
        body: 'The band is connected, but it has not sent a history record to Edge yet.',
        next: 'Keep the band nearby for a minute. If this does not change, tap Sync now to start a fresh connection.',
        icon: LucideIcons.clock3,
        working: true,
      );
    }
    return _SyncExplanation(
      title: 'Sync complete',
      body: 'The latest stored strap recording is from ${_when(app.lastRecordAt)}.',
      next: 'You can leave the app open for live heart rate, or sync again later for new history.',
      icon: LucideIcons.circleCheck,
      working: false,
    );
  }

  String _when(DateTime? value) {
    if (value == null) return 'Not available yet';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _age(DateTime? value) {
    if (value == null) return 'unknown';
    final seconds = DateTime.now().difference(value).inSeconds;
    if (seconds < 0) return 'clock ahead';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }

  String _diagnostics(AppState app) {
    final device = app.device;
    return [
      'connection=${device.connection}',
      'battery=${device.batteryPct?.round() ?? 'unknown'}',
      'charging=${device.charging == true}',
      'wrist=${device.wristOn == null ? 'unknown' : device.wristOn! ? 'on' : 'off'}',
      'last_ble=${app.lastDataAt?.toIso8601String() ?? 'unknown'}',
      'last_record=${app.lastRecordAt?.toIso8601String() ?? 'unknown'}',
      'syncing=${app.syncingNow}',
      'deriving=${app.deriving}',
      'derive_pending=${app.derivePending}',
      'stream=${app.syncSnapshot}',
      'phone_steps_enabled=${app.phoneStepsEnabled}',
      'phone_steps_today=${app.phoneStepsToday}',
      'phone_steps_last_error=${app.phoneStepsLastError ?? 'none'}',
      'events:',
      ...app.logLines.reversed.take(20),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final device = app.device;
    final status = app.engine.bandStatus;
    final receiving = app.syncingNow;
    final deriving = app.deriving;
    final pending = app.derivePending;
    final stream = app.syncSnapshot;
    final connected = device.connection == 'connected';
    final bleStale = connected && isBleStale(
      app.lastDataAt,
      now: DateTime.now(),
    );
    final explanation = _explain(
      app: app,
      connected: connected,
      receiving: receiving,
      deriving: deriving,
      pending: pending,
      bleStale: bleStale,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sync details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: explanation.working
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(explanation.icon, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(explanation.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(explanation.body),
                        const SizedBox(height: 10),
                        Text('Next: ${explanation.next}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Progress is shown as verified stages, not a made-up percentage: Bluetooth connection, records saved locally, then health calculations.',
          ),
          const SizedBox(height: 20),
          _Stage(
            icon: LucideIcons.bluetooth,
            title: 'Bluetooth link',
            detail: '${device.connection} · ${status.title}',
            done: connected,
            active: !connected && device.connection == 'connecting',
          ),
          _Stage(
            icon: LucideIcons.download,
            title: 'Receive and store',
            detail: receiving
                ? 'Records are arriving now'
                : bleStale
                ? 'No BLE notification for ${_age(app.lastDataAt)}'
                : 'Last strap record: ${_when(app.lastRecordAt)}',
            done: app.lastRecordAt != null && !receiving && !bleStale,
            active: receiving,
          ),
          _Stage(
            icon: LucideIcons.activity,
            title: 'Derive metrics',
            detail: deriving
                ? 'Calculating sleep, recovery and strain'
                : pending
                ? 'Queued behind the settling window'
                : 'No derivation currently running',
            done: app.lastRecordAt != null && !deriving && !pending,
            active: deriving || pending,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live data stream',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'These are live counters from the WHOOP transfer — they '
                    'change only when the band actually sends data.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _StreamRow('History transfer',
                      stream['active'] == true ? 'active' : 'idle'),
                  _StreamRow('Frames waiting to decode',
                      '${stream['queued_frames'] ?? 0}'),
                  _StreamRow('Records seen from WHOOP',
                      '${stream['records_seen'] ?? 0}'),
                  _StreamRow('Batches safely stored',
                      '${stream['batches_acked'] ?? 0}'),
                  _StreamRow('Records buffered for next save',
                      '${stream['buffered_records'] ?? 0}'),
                  _StreamRow('History requests / completed',
                      '${stream['history_requests'] ?? 0} / ${stream['history_completions'] ?? 0}'),
                  _StreamRow('Last BLE packet', _age(app.lastDataAt)),
                  _StreamRow('Newest stored band record', _when(app.lastRecordAt)),
                  if (stream['history_stuck'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'History transfer stopped defensively. The band kept '
                        'its checkpoint; reconnecting is safe.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diagnostics',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text('Last BLE notification: ${_when(app.lastDataAt)}'),
                  Text('BLE activity age: ${_age(app.lastDataAt)}'),
                  Text('Last stored strap record: ${_when(app.lastRecordAt)}'),
                  Text('Stored-record age: ${_age(app.lastRecordAt)}'),
                  Text(
                    'Battery: ${device.batteryPct == null ? 'unknown' : '${device.batteryPct!.round()}%'}',
                  ),
                  Text(
                    'Wrist: ${device.wristOn == null
                        ? 'unknown'
                        : device.wristOn!
                        ? 'on'
                        : 'off'}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Step source',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    app.phoneStepsEnabled
                        ? 'Phone pedometer enabled · ${app.phoneStepsToday} today'
                        : 'Phone pedometer is off',
                  ),
                  if (app.phoneStepsLastSyncedDays case final days?)
                    Text(
                      'Phone coverage synced: $days day${days == 1 ? '' : 's'}',
                    ),
                  if (app.phoneStepsLastTotal case final total?)
                    Text('Phone steps imported: $total'),
                  if (app.phoneStepsLastError case final error?)
                    Text(
                      'Phone-step sync error: $error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  const Text(
                    'WHOOP 4 all-day steps are not claimed unless a validated strap counter is available.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (app.logLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                initiallyExpanded: receiving || bleStale,
                leading: const Icon(LucideIcons.list),
                title: const Text('Live protocol events'),
                subtitle: Text('${app.logLines.length} local events recorded'),
                children: [
                  for (final line in app.logLines.take(12))
                    ListTile(
                      dense: true,
                      title: Text(line, style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _diagnostics(app)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied locally')),
                );
              }
            },
            icon: const Icon(LucideIcons.copy),
            label: const Text('Copy diagnostics'),
          ),
          if (status.isFault) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(status.reason),
                    if (status.fix case final fix?) ...[
                      const SizedBox(height: 6),
                      Text('Next: $fix'),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: receiving ? null : app.syncNow,
            icon: const Icon(LucideIcons.refreshCw),
            label: Text(receiving ? 'Syncing…' : 'Sync now'),
          ),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.icon,
    required this.title,
    required this.detail,
    required this.done,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? Colors.green
        : active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(done ? LucideIcons.circleCheck : icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(detail),
      trailing: active
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _StreamRow extends StatelessWidget {
  const _StreamRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _SyncExplanation {
  const _SyncExplanation({
    required this.title,
    required this.body,
    required this.next,
    required this.icon,
    required this.working,
  });

  final String title;
  final String body;
  final String next;
  final IconData icon;
  final bool working;
}
