import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';

/// "Count to 10" kick counting, tracked per baby for twins.
class KickCounterScreen extends StatefulWidget {
  const KickCounterScreen({super.key});

  @override
  State<KickCounterScreen> createState() => _KickCounterScreenState();
}

class _KickCounterScreenState extends State<KickCounterScreen> {
  String _babyLabel = 'A';
  KickSession? _active;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final scheme = Theme.of(context).colorScheme;
    final history = store.kickSessions
        .where((s) => s.ended && (!p.isTwins || s.babyLabel == _babyLabel))
        .take(10)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kick counter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.isTwins) ...[
            SegmentedButton<String>(
              segments: [
                for (final b in p.babies)
                  ButtonSegment(value: b.label, label: Text(b.displayName)),
              ],
              selected: {_babyLabel},
              onSelectionChanged: _active != null
                  ? null
                  : (s) => setState(() => _babyLabel = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              'Count each baby separately — they have their own movement patterns.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          _counterCard(context, store, p),
          const SizedBox(height: 16),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSecondaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    'Pick a time when baby is usually active (often after a meal). '
                    'Lie on your left side, start the session, and tap for every kick, roll or flutter. '
                    'Most babies reach 10 movements within an hour or two.\n\n'
                    'If movements take much longer than usual, or you notice a clear slow-down, '
                    'contact your doctor the same day — do not wait until tomorrow.',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (history.isNotEmpty) ...[
            Text('Recent sessions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final s in history)
              Card(
                color: scheme.surfaceContainerHigh,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text('${s.kicks.length}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary)),
                  ),
                  title: Text(s.minutesToTen != null
                      ? '10 kicks in ${s.minutesToTen} min'
                      : '${s.kicks.length} kicks recorded'),
                  subtitle: Text(
                      '${p.isTwins ? '${p.babies.firstWhere((b) => b.label == s.babyLabel, orElse: () => p.babies.first).displayName} · ' : ''}${DateFormat('EEE d MMM, h:mm a').format(s.start)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => store.deleteKickSession(s.id),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _counterCard(BuildContext context, AppStore store, PregnancyProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final active = _active;
    final count = active?.kicks.length ?? 0;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (active == null) ...[
              Icon(Icons.touch_app_outlined, size: 48, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                p.isTwins
                    ? 'Counting for ${p.babies.firstWhere((b) => b.label == _babyLabel).displayName}'
                    : 'Ready when you feel movement',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _active = KickSession(
                    id: store.newId(),
                    babyLabel: _babyLabel,
                    start: DateTime.now(),
                  );
                }),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start session'),
              ),
            ] else ...[
              Text(
                '$count',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer),
              ),
              Text('of 10 kicks',
                  style: TextStyle(color: scheme.onPrimaryContainer)),
              const SizedBox(height: 4),
              Text(
                'Started ${DateFormat('h:mm a').format(active.start)}',
                style: TextStyle(
                    fontSize: 12, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 88,
                child: FilledButton(
                  onPressed: () async {
                    setState(() => active.kicks.add(DateTime.now()));
                    if (active.kicks.length >= 10) {
                      active.ended = true;
                      final messenger = ScaffoldMessenger.of(context);
                      await store.upsertKickSession(active);
                      if (mounted) setState(() => _active = null);
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                            '10 kicks in ${active.minutesToTen} minutes — saved!'),
                      ));
                    }
                  },
                  child: const Text('KICK!',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  active.ended = true;
                  if (active.kicks.isNotEmpty) {
                    await store.upsertKickSession(active);
                  }
                  setState(() => _active = null);
                },
                child: const Text('End session early'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
