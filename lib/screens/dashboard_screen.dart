import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';
import '../weekly_content.dart';
import 'weight_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final week = PregnancyMath.gaWeeks(p);
    final info = WeeklyContent.forWeek(week);
    final guidance = PregnancyMath.deliveryGuidance(p);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(context, p, guidance.window),
            const SizedBox(height: 16),
            if (p.isTwins) _twinCards(context, p, info) else _singleCard(context, p, info),
            const SizedBox(height: 16),
            _todayTip(context, info),
            const SizedBox(height: 16),
            _nextAppointment(context, store),
            const SizedBox(height: 16),
            _medsToday(context, store),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _waterCard(context, store)),
                const SizedBox(width: 16),
                Expanded(child: _weightCard(context, store)),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Educational information only — always follow your doctor\'s advice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, PregnancyProfile p, String window) {
    final scheme = Theme.of(context).colorScheme;
    final daysToGo = PregnancyMath.daysToGo(p);
    final trimester = PregnancyMath.trimester(p);

    // Twins count down to their own typical arrival window, not the
    // 40-week EDD — that date is a singleton-scale reference.
    final aw = PregnancyMath.arrivalWindow(p);
    final windowStart = PregnancyMath.dateAtWeek(p, aw.startWeek);
    final windowEnd = PregnancyMath.dateAtWeek(p, aw.endWeek);
    final today = PregnancyMath.dateOnly(DateTime.now());
    final daysToWindow = windowStart.difference(today).inDays;
    final dateFmt = DateFormat('d MMM');

    final String countdownLabel;
    if (daysToWindow > 0) {
      countdownLabel = p.isTwins
          ? '~$daysToWindow days to arrival window'
          : (daysToGo >= 0 ? '$daysToGo days to EDD' : 'Past EDD');
    } else if (!today.isAfter(windowEnd)) {
      countdownLabel = 'In the typical arrival window';
    } else {
      countdownLabel = p.isTwins ? 'Past the typical window' : 'Past EDD';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.isTwins ? 'Your twins' : 'Your baby',
            style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            PregnancyMath.gaLabel(p),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Trimester $trimester'),
              _chip(context, countdownLabel),
              _chip(
                  context,
                  'Typical arrival: $window'
                  '${p.isTwins ? ' (${dateFmt.format(windowStart)} – ${dateFmt.format(windowEnd)})' : ''}'),
              if (p.isTwins && p.chorionicity != null && p.chorionicity != Chorionicity.unknown)
                _chip(context, p.chorionicity!.shortName),
            ],
          ),
          if (p.isTwins) ...[
            const SizedBox(height: 10),
            Text(
              'The 40-week due date (${DateFormat('d MMM').format(p.edd)}) is a singleton-scale reference — '
              '${switch (p.chorionicity) {
                Chorionicity.dcda => 'di-di',
                Chorionicity.mcda => 'mo-di',
                Chorionicity.mcma => 'mo-mo',
                _ => 'most'
              }} twins arrive earlier. Your doctor sets the actual plan.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _babyCard(BuildContext context, String name, WeekInfo info, {String? note}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.child_care, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Size of a ${info.size.toLowerCase()}'),
            Text(info.approx, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _singleCard(BuildContext context, PregnancyProfile p, WeekInfo info) {
    return _babyCard(context, p.babies.first.displayName, info);
  }

  Widget _twinCards(BuildContext context, PregnancyProfile p, WeekInfo info) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _babyCard(context, p.babies[0].displayName, info)),
            const SizedBox(width: 12),
            Expanded(child: _babyCard(context, p.babies[1].displayName, info)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Twins often measure a little smaller than singleton averages in the third trimester — your doctor tracks each baby\'s own growth curve.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _todayTip(BuildContext context, WeekInfo info) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text('This week', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSecondaryContainer)),
              ],
            ),
            const SizedBox(height: 8),
            Text(info.development, style: TextStyle(color: scheme.onSecondaryContainer)),
            const SizedBox(height: 8),
            for (final t in info.tips)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: TextStyle(color: scheme.onSecondaryContainer)),
                    Expanded(child: Text(t, style: TextStyle(color: scheme.onSecondaryContainer))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nextAppointment(BuildContext context, AppStore store) {
    final next = store.nextAppointment;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.tertiaryContainer,
          child: Icon(Icons.event, color: scheme.onTertiaryContainer),
        ),
        title: Text(next == null ? 'No upcoming appointment' : next.title),
        subtitle: Text(next == null
            ? 'Add one from the More tab'
            : '${DateFormat('EEE, d MMM').format(next.dateTime)} · ${DateFormat('h:mm a').format(next.dateTime)} · ${next.type.label}'),
      ),
    );
  }

  Widget _medsToday(BuildContext context, AppStore store) {
    final meds = store.medicines.where((m) => m.active).toList();
    if (meds.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today\'s medicines', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final m in meds)
              for (final slot in m.slots)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('${m.name}${m.dose.isEmpty ? '' : ' — ${m.dose}'}'),
                  subtitle: Text(slot),
                  value: store.isMedTaken(today, m.id, slot),
                  onChanged: (_) => store.toggleMedTaken(today, m.id, slot),
                ),
          ],
        ),
      ),
    );
  }

  Widget _waterCard(BuildContext context, AppStore store) {
    final scheme = Theme.of(context).colorScheme;
    final glasses = store.waterToday();
    const target = 10;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: scheme.primary, size: 20),
                const SizedBox(width: 6),
                const Text('Water', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text('$glasses / $target glasses'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (glasses / target).clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  onPressed: glasses > 0 ? () => store.setWaterToday(glasses - 1) : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const Spacer(),
                IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => store.setWaterToday(glasses + 1),
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightCard(BuildContext context, AppStore store) {
    final scheme = Theme.of(context).colorScheme;
    final weights = store.weights;
    final latest = weights.isEmpty ? null : weights.last;
    final delta = weights.length >= 2 ? weights.last.kg - weights.first.kg : null;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WeightScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monitor_weight_outlined, color: scheme.primary, size: 20),
                  const SizedBox(width: 6),
                  const Text('Weight', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Text(latest == null ? 'Not logged yet' : '${latest.kg.toStringAsFixed(1)} kg'),
              const SizedBox(height: 4),
              Text(
                delta == null
                    ? 'Tap to log'
                    : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg overall',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
