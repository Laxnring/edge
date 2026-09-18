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
    final connected = device.connection == 'connected';
    final bleStale = connected && isBleStale(
      app.lastDataAt,
      now: DateTime.now(),
    );
    final complete =
        connected &&
        !receiving &&
        !deriving &&
        !pending &&
        app.lastRecordAt != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            receiving
                ? 'Receiving recordings'
                : deriving || pending
                ? 'Processing recordings'
                : complete
                        ? 'No sync currently running'
                : 'Waiting for the band',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'These are the actual stages OpenStrap can verify. A quiet link is '
            'not treated as a fake percentage or a claim that every record has arrived.',
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
            active: receiving || bleStale,
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
                leading: const Icon(LucideIcons.list),
                title: const Text('Recent engine events'),
                subtitle: Text('${app.logLines.length} local events recorded'),
                children: [
                  for (final line in app.logLines.reversed.take(8))
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
