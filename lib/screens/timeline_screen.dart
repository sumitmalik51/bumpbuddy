import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pregnancy_math.dart';
import '../store.dart';
import '../weekly_content.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _controller = ScrollController();
  bool _jumped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final currentWeek = PregnancyMath.gaWeeks(p).clamp(4, 40);
    final guidance = PregnancyMath.deliveryGuidance(p);
    final schedule = PregnancyMath.scanSchedule(p);
    final weeks = [for (var w = 4; w <= guidance.horizonWeek; w++) w];

    // Jump near the current week on first build.
    if (!_jumped) {
      _jumped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        final idx = weeks.indexOf(currentWeek);
        if (idx > 2) {
          _controller.jumpTo((idx - 1) * 150.0);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                guidance.note,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.all(16),
        itemCount: weeks.length,
        itemBuilder: (context, i) {
          final w = weeks[i];
          final info = WeeklyContent.forWeek(w);
          final scans = schedule.where((s) => s.week == w).toList();
          return _weekCard(context, w, currentWeek, info, scans);
        },
      ),
    );
  }

  Widget _weekCard(
    BuildContext context,
    int week,
    int currentWeek,
    WeekInfo info,
    List<({int week, String title, String detail})> scans,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = week == currentWeek;
    final isPast = week < currentWeek;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: isCurrent ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isCurrent,
            leading: CircleAvatar(
              backgroundColor: isCurrent
                  ? scheme.primary
                  : (isPast ? scheme.surfaceContainerHighest : scheme.secondaryContainer),
              child: Text(
                '$week',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
            title: Text(
              'Week $week${isCurrent ? ' — you are here' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Size of a ${info.size.toLowerCase()} · ${info.approx}'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.development),
              if (scans.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final s in scans)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medical_services_outlined,
                                size: 18, color: scheme.onTertiaryContainer),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(s.title,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onTertiaryContainer)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(s.detail,
                            style: TextStyle(
                                fontSize: 13, color: scheme.onTertiaryContainer)),
                      ],
                    ),
                  ),
              ],
              if (info.tips.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final t in info.tips)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(t)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
