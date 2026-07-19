import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';

/// Labour contraction timer with 5-1-1 pattern awareness.
class ContractionTimerScreen extends StatefulWidget {
  const ContractionTimerScreen({super.key});

  @override
  State<ContractionTimerScreen> createState() =>
      _ContractionTimerScreenState();
}

class _ContractionTimerScreenState extends State<ContractionTimerScreen> {
  Contraction? _running;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start(AppStore store) {
    HapticFeedback.mediumImpact();
    setState(() {
      _running = Contraction(id: store.newId(), start: DateTime.now());
    });
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() {}));
  }

  Future<void> _stop(AppStore store) async {
    HapticFeedback.mediumImpact();
    final c = _running!;
    c.durationSec = DateTime.now().difference(c.start).inSeconds;
    _ticker?.cancel();
    setState(() => _running = null);
    if (c.durationSec >= 5) {
      await store.upsertContraction(c);
    }
  }

  /// Stats over the last hour of completed contractions.
  ({int count, double? avgGapMin, double? avgDurSec, bool fiveOneOne})
      _lastHourStats(List<Contraction> all) {
    final now = DateTime.now();
    final recent = all
        .where((c) =>
            c.durationSec > 0 &&
            now.difference(c.start).inMinutes <= 70)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (recent.length < 2) {
      return (
        count: recent.length,
        avgGapMin: null,
        avgDurSec: recent.isEmpty
            ? null
            : recent.map((c) => c.durationSec).reduce((a, b) => a + b) /
                recent.length,
        fiveOneOne: false
      );
    }
    final gaps = <double>[];
    for (var i = 1; i < recent.length; i++) {
      gaps.add(recent[i]
              .start
              .difference(recent[i - 1].start)
              .inSeconds /
          60.0);
    }
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    final avgDur =
        recent.map((c) => c.durationSec).reduce((a, b) => a + b) /
            recent.length;
    final spanMin =
        recent.last.start.difference(recent.first.start).inMinutes;
    final fiveOneOne =
        avgGap <= 5.5 && avgDur >= 55 && spanMin >= 55 && recent.length >= 6;
    return (
      count: recent.length,
      avgGapMin: avgGap,
      avgDurSec: avgDur,
      fiveOneOne: fiveOneOne
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final scheme = Theme.of(context).colorScheme;
    final stats = _lastHourStats(store.contractions);
    final running = _running;
    final elapsed = running == null
        ? 0
        : DateTime.now().difference(running.start).inSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contraction timer'),
        actions: [
          if (store.contractions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear history',
              onPressed: () => store.clearContractions(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (stats.fiveOneOne)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.emergency, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your pattern matches the 5-1-1 rule (about every 5 minutes, '
                        '~1 minute long, for an hour) — call your care team now.'
                        '${p.isTwins ? ' Twin labours can move quickly; teams usually want an early call.' : ''}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    running == null
                        ? 'When one starts, tap the button'
                        : '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}',
                    style: running == null
                        ? TextStyle(color: scheme.onPrimaryContainer)
                        : Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 88,
                    child: FilledButton(
                      style: running != null
                          ? FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError)
                          : null,
                      onPressed: () =>
                          running == null ? _start(store) : _stop(store),
                      child: Text(
                        running == null
                            ? 'CONTRACTION STARTED'
                            : 'IT\'S OVER',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(context, 'Last hour', '${stats.count}'),
              _stat(
                  context,
                  'Avg gap',
                  stats.avgGapMin == null
                      ? '—'
                      : '${stats.avgGapMin!.toStringAsFixed(1)} min'),
              _stat(
                  context,
                  'Avg length',
                  stats.avgDurSec == null
                      ? '—'
                      : '${stats.avgDurSec!.round()} s'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'The 5-1-1 rule is a common guide for full-term labour — your doctor may have '
            'given you a different plan${p.isTwins ? ' (usual for twins)' : ''}. When in doubt, call.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (store.contractions.isNotEmpty) ...[
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < store.contractions.length && i < 30; i++)
              Builder(builder: (context) {
                final c = store.contractions[i];
                final next = i + 1 < store.contractions.length
                    ? store.contractions[i + 1]
                    : null;
                final gapMin = next == null
                    ? null
                    : c.start.difference(next.start).inSeconds / 60.0;
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: Text(DateFormat('h:mm a').format(c.start)),
                    title: Text('${c.durationSec} s long'),
                    subtitle: gapMin == null
                        ? null
                        : Text(
                            '${gapMin.toStringAsFixed(1)} min after the previous one'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => store.deleteContraction(c.id),
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
