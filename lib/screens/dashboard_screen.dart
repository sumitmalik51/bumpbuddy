import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';
import '../weekly_content.dart';
import 'chat_screen.dart';
import 'contraction_timer_screen.dart';
import 'growth_screen.dart';
import 'kick_counter_screen.dart';
import 'scan_read_screen.dart';
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

    if (p.delivered) {
      return _deliveredView(context, p);
    }

    final cards = <Widget>[
      _header(context, p, guidance.window),
      const SizedBox(height: 16),
      if (p.isTwins) _twinCards(context, p, info) else _singleCard(context, p, info),
      const SizedBox(height: 16),
      _growthCard(context, store, p),
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
      const SizedBox(height: 16),
      _kickCard(context, store, p),
      if (week >= 30) ...[
        const SizedBox(height: 16),
        Card(
          color: scheme.surfaceContainerHigh,
          child: ListTile(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ContractionTimerScreen())),
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.timer_outlined, color: scheme.primary),
            ),
            title: const Text('Contraction timer'),
            subtitle: const Text('Times each one, watches for the 5-1-1 pattern'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ],
      const SizedBox(height: 24),
      Center(
        child: Text(
          'Educational information only — always follow your doctor\'s advice.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.outline),
        ),
      ),
      const SizedBox(height: 8),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < cards.length; i++)
              _StaggeredEntrance(index: i ~/ 2, child: cards[i]),
          ],
        ),
      ),
    );
  }

  Widget _deliveredView(BuildContext context, PregnancyProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final names = p.babies.map((b) => b.displayName).join(' & ');
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome to the world, $names!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold),
                  ),
                  if (p.deliveredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Born ${DateFormat('d MMMM yyyy').format(p.deliveredAt!)}',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: scheme.surfaceContainerHigh,
              child: ListTile(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GrowthScreen())),
                leading: CircleAvatar(
                  backgroundColor: scheme.tertiaryContainer,
                  child:
                      Icon(Icons.show_chart, color: scheme.onTertiaryContainer),
                ),
                title: const Text('Pregnancy growth history'),
                subtitle: const Text('All scans and curves, kept safe'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Pregnancy reminders are off. Your records, journal and growth charts stay in their tabs — take them along to paediatric visits.',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSecondaryContainer),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _growthCard(BuildContext context, AppStore store, PregnancyProfile p) {
    final scheme = Theme.of(context).colorScheme;
    // Latest AI-read scan, if any.
    String subtitle = p.isTwins
        ? 'AI-read your scans to see both babies\' curves'
        : 'AI-read your scans to see the growth curve';
    for (final r in store.records) {
      if (r.category == RecordCategory.ultrasound && r.aiJson.isNotEmpty) {
        subtitle = 'Scan history & weight curves';
        break;
      }
    }
    return Column(
      children: [
        Card(
          color: scheme.primaryContainer,
          child: ListTile(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanReadScreen())),
            leading: CircleAvatar(
              backgroundColor: scheme.primary,
              child: Icon(Icons.auto_awesome, color: scheme.onPrimary),
            ),
            title: const Text('Read a scan report',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Photograph the pages — AI fills in the measurements'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: scheme.surfaceContainerHigh,
          child: ListTile(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ChatScreen())),
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(Icons.chat_bubble_outline,
                  color: scheme.onSecondaryContainer),
            ),
            title: const Text('Ask BumpBuddy'),
            subtitle: const Text('Questions answered from YOUR data'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: scheme.surfaceContainerHigh,
          child: ListTile(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const GrowthScreen())),
            leading: CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(Icons.show_chart, color: scheme.onTertiaryContainer),
            ),
            title: const Text('Growth'),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ],
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: _FloatingHearts(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _headerContent(context, p, window, daysToGo, trimester,
              countdownLabel, windowStart, windowEnd, dateFmt),
        ),
      ),
    );
  }

  Widget _headerContent(
      BuildContext context,
      PregnancyProfile p,
      String window,
      int daysToGo,
      int trimester,
      String countdownLabel,
      DateTime windowStart,
      DateTime windowEnd,
      DateFormat dateFmt) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
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
        ]);
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
                _PulsingHeart(
                  child: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.favorite, color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(WeeklyContent.emojiForWeek(
                        PregnancyMath.gaWeeks(context.read<AppStore>().profile!)),
                    style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Size of a ${info.size.toLowerCase()}'),
                      Text(info.approx,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (glasses / target).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
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

  Widget _kickCard(BuildContext context, AppStore store, PregnancyProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final week = PregnancyMath.gaWeeks(p);
    final todaySessions = store.kickSessions
        .where((s) =>
            AppStore.dayKey(s.start) == AppStore.dayKey(DateTime.now()))
        .toList();
    final String subtitle;
    if (todaySessions.isEmpty) {
      subtitle = week >= 28
          ? 'No session today yet — daily counting matters from 28 weeks'
          : 'Track movements once kicks are regular';
    } else if (p.isTwins) {
      final labels = todaySessions.map((s) => s.babyLabel).toSet();
      subtitle =
          'Today: ${todaySessions.length} session(s) · ${labels.map((l) => 'Baby $l').join(' & ')}';
    } else {
      final best = todaySessions
          .map((s) => s.minutesToTen)
          .whereType<int>()
          .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
      subtitle = best != null
          ? 'Today: 10 kicks in $best min'
          : 'Today: ${todaySessions.length} session(s)';
    }
    return Card(
      color: scheme.surfaceContainerHigh,
      child: ListTile(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KickCounterScreen())),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.touch_app_outlined, color: scheme.primary),
        ),
        title: const Text('Kick counter'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
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

/// Fade + gentle slide-up entrance, staggered by [index].
class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

/// A slow, calm heartbeat pulse (used on baby-card avatars).
class _PulsingHeart extends StatefulWidget {
  final Widget child;
  const _PulsingHeart({required this.child});

  @override
  State<_PulsingHeart> createState() => _PulsingHeartState();
}

class _PulsingHeartState extends State<_PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.94, end: 1.06).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Soft hearts drifting slowly upward behind the header content.
class _FloatingHearts extends StatefulWidget {
  final Color color;
  final Widget child;
  const _FloatingHearts({required this.color, required this.child});

  @override
  State<_FloatingHearts> createState() => _FloatingHeartsState();
}

class _FloatingHeartsState extends State<_FloatingHearts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter:
                    _HeartsPainter(t: _controller.value, color: widget.color),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _HeartsPainter extends CustomPainter {
  final double t;
  final Color color;
  _HeartsPainter({required this.t, required this.color});

  // (xFraction, size, phase) per heart — fixed so motion is deterministic.
  static const _hearts = [
    (0.12, 14.0, 0.0),
    (0.34, 9.0, 0.35),
    (0.58, 12.0, 0.62),
    (0.78, 8.0, 0.15),
    (0.92, 11.0, 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (xf, s, phase) in _hearts) {
      final cycle = (t + phase) % 1.0;
      final y = size.height * (1.15 - 1.35 * cycle);
      final x = size.width * xf + 6 * (cycle * 6.28).remainder(6.28).clamp(0, 1);
      canvas.drawPath(_heartPath(Offset(x, y), s), paint);
    }
  }

  Path _heartPath(Offset c, double s) {
    return Path()
      ..moveTo(c.dx, c.dy + 0.35 * s)
      ..cubicTo(c.dx, c.dy + 0.1 * s, c.dx - 0.5 * s, c.dy - 0.05 * s,
          c.dx - 0.5 * s, c.dy - 0.3 * s)
      ..cubicTo(c.dx - 0.5 * s, c.dy - 0.55 * s, c.dx - 0.15 * s,
          c.dy - 0.55 * s, c.dx, c.dy - 0.3 * s)
      ..cubicTo(c.dx + 0.15 * s, c.dy - 0.55 * s, c.dx + 0.5 * s,
          c.dy - 0.55 * s, c.dx + 0.5 * s, c.dy - 0.3 * s)
      ..cubicTo(c.dx + 0.5 * s, c.dy - 0.05 * s, c.dx, c.dy + 0.1 * s, c.dx,
          c.dy + 0.35 * s)
      ..close();
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => old.t != t;
}
