import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ai/scan_reader.dart';
import '../growth_reference.dart';
import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';

/// Fixed per-baby identity colors (validated for CVD + contrast on both
/// light and dark surfaces). Baby A is always rose, Baby B always violet —
/// the same identities as the app icon. Color follows the entity everywhere.
const babyAColor = Color(0xFFC2568A);
const babyBColor = Color(0xFF8A56C2);

Color babyColor(String label) => label == 'B' ? babyBColor : babyAColor;

class _ScanPoint {
  final DateTime date;
  final String? gaLabel;
  final Map<String, double> efw; // baby label -> grams
  final double? discordance; // derived (preferred) or printed
  _ScanPoint({
    required this.date,
    required this.gaLabel,
    required this.efw,
    required this.discordance,
  });
}

List<_ScanPoint> _scanPoints(AppStore store) {
  final points = <_ScanPoint>[];
  for (final r in store.records) {
    if (r.category != RecordCategory.ultrasound || r.aiJson.isEmpty) continue;
    Map<String, dynamic> j;
    try {
      j = jsonDecode(r.aiJson) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }
    final efw = <String, double>{};
    for (final b in ((j['babies'] ?? []) as List)) {
      final m = b as Map<String, dynamic>;
      if (m['efw_grams'] is num) {
        efw[(m['label'] ?? 'A') as String] = (m['efw_grams'] as num).toDouble();
      }
    }
    if (efw.isEmpty) continue;
    DateTime date = r.date;
    final rd = j['report_date'];
    if (rd is String) {
      final parsed = DateTime.tryParse(rd);
      if (parsed != null) date = parsed;
    }
    double? disc;
    final derived = j['derived'];
    if (derived is Map && derived['efw_discordance_percent'] is num) {
      disc = (derived['efw_discordance_percent'] as num).toDouble();
    } else if (j['printed_efw_discordance_percent'] is num) {
      disc = (j['printed_efw_discordance_percent'] as num).toDouble();
    } else if (efw.length >= 2) {
      final computed = ScanReader.computeDiscordance(j);
      if (computed['efw_discordance_percent'] is num) {
        disc = (computed['efw_discordance_percent'] as num).toDouble();
      }
    }
    points.add(_ScanPoint(
      date: date,
      gaLabel: j['gestational_age_on_report'] as String?,
      efw: efw,
      discordance: disc,
    ));
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final scheme = Theme.of(context).colorScheme;
    final points = _scanPoints(store);
    final labels = p.isTwins ? ['A', 'B'] : ['A'];

    return Scaffold(
      appBar: AppBar(title: const Text('Growth')),
      body: points.isEmpty
          ? _empty(context)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (labels.length > 1) _legend(context, p),
                const SizedBox(height: 8),
                Card(
                  color: scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: SizedBox(
                      height: 240,
                      child: _EfwChart(
                        points: points,
                        labels: labels,
                        profile: p,
                        selected: _selected,
                        onSelect: (i) => setState(
                            () => _selected = _selected == i ? null : i),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Estimated fetal weight (g) per scan — tap a point for details.\n'
                    'Shaded band: Hadlock 10th–90th centile, dashes: 50th (singleton reference'
                    '${p.isTwins ? '; twins often track lower near term' : ''}).',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11.5, color: scheme.outline),
                  ),
                ),
                const SizedBox(height: 12),
                if (_selected != null)
                  _scanDetailCard(context, p, points, _selected!),
                if (points.length >= 2) ...[
                  const SizedBox(height: 4),
                  _deltaSection(context, p, points, labels),
                ],
                if (p.isTwins) ...[
                  const SizedBox(height: 16),
                  _discordanceSection(context, points),
                ],
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Values are AI-read from your reports — verify against the originals. '
                    'Growth interpretation always belongs to your doctor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            const Text(
              'No scan data yet.\n\nAttach a growth-scan photo to an Ultrasound record and tap "Read with AI" — every scan you read appears here as a growth curve.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, PregnancyProfile p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final b in p.babies) ...[
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: babyColor(b.label),
              shape: b.label == 'B' ? BoxShape.rectangle : BoxShape.circle,
              borderRadius:
                  b.label == 'B' ? BorderRadius.circular(3) : null,
            ),
          ),
          Text(b.displayName, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _scanDetailCard(BuildContext context, PregnancyProfile p,
      List<_ScanPoint> points, int i) {
    final scheme = Theme.of(context).colorScheme;
    final pt = points[i];
    final prev = i > 0 ? points[i - 1] : null;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('EEE, d MMM yyyy').format(pt.date)}'
              '${pt.gaLabel != null ? ' · ${pt.gaLabel}' : ''}',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 6),
            for (final b in p.babies)
              if (pt.efw[b.label] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Builder(builder: (context) {
                    final ga = PregnancyMath.gaDays(p, pt.date) / 7.0;
                    final centile =
                        centileLabelFor(ga, pt.efw[b.label]!);
                    return Text(
                      '${b.displayName}: ${pt.efw[b.label]!.round()} g'
                      '${prev != null && prev.efw[b.label] != null ? '  (+${(pt.efw[b.label]! - prev.efw[b.label]!).round()} g since ${DateFormat('d MMM').format(prev.date)})' : ''}'
                      '${centile != null ? '\n   $centile' : ''}',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSecondaryContainer),
                    );
                  }),
                ),
            if (pt.discordance != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Weight difference between twins: ${pt.discordance!.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSecondaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deltaSection(BuildContext context, PregnancyProfile p,
      List<_ScanPoint> points, List<String> labels) {
    final scheme = Theme.of(context).colorScheme;
    final last = points.last;
    final prev = points[points.length - 2];
    final days = last.date.difference(prev.date).inDays;
    return Row(
      children: [
        for (final label in labels)
          if (last.efw[label] != null && prev.efw[label] != null)
            Expanded(
              child: Card(
                color: scheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: babyColor(label),
                              shape: label == 'B'
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: label == 'B'
                                  ? BorderRadius.circular(2)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.babies
                                  .firstWhere((b) => b.label == label,
                                      orElse: () => Baby(label: label))
                                  .displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+${(last.efw[label]! - prev.efw[label]!).round()} g',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'in $days days'
                        '${days >= 7 ? ' (~${((last.efw[label]! - prev.efw[label]!) / days * 7).round()} g/week)' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _discordanceSection(BuildContext context, List<_ScanPoint> points) {
    final scheme = Theme.of(context).colorScheme;
    final withDisc = points.where((p) => p.discordance != null).toList();
    if (withDisc.isEmpty) return const SizedBox.shrink();
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Twin weight difference over time',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < withDisc.length; i++) ...[
                  if (i > 0)
                    Icon(
                      withDisc[i].discordance! >
                              withDisc[i - 1].discordance!
                          ? Icons.arrow_upward
                          : withDisc[i].discordance! <
                                  withDisc[i - 1].discordance!
                              ? Icons.arrow_downward
                              : Icons.arrow_forward,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: withDisc[i].discordance! >= 20
                          ? scheme.errorContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${DateFormat('d MMM').format(withDisc[i].date)} · ${withDisc[i].discordance!.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: withDisc[i].discordance! >= 20
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Doctors usually take a closer look when the difference reaches about 20%. '
              'Your care team tracks this on every twin growth scan.',
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time-proportional EFW line chart. Marks per the dataviz spec: 2px lines,
/// 8px markers with a 2px surface ring (circle = A, rounded square = B),
/// recessive hairline grid, muted text labels, direct end-labels, animated
/// draw-in.
class _EfwChart extends StatelessWidget {
  final List<_ScanPoint> points;
  final List<String> labels;
  final PregnancyProfile profile;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _EfwChart({
    required this.points,
    required this.labels,
    required this.profile,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => GestureDetector(
        onTapUp: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final x = d.localPosition.dx;
          var best = 0;
          var bestDist = double.infinity;
          for (var i = 0; i < points.length; i++) {
            final px = _xFor(i, box.size.width);
            final dist = (px - x).abs();
            if (dist < bestDist) {
              bestDist = dist;
              best = i;
            }
          }
          if (bestDist < 48) onSelect(best);
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _EfwChartPainter(
            points: points,
            labels: labels,
            progress: progress,
            selected: selected,
            surface: scheme.surfaceContainerHigh,
            gridColor: scheme.onSurfaceVariant.withValues(alpha: 0.18),
            textColor: scheme.onSurfaceVariant,
            bandColor: scheme.onSurfaceVariant.withValues(alpha: 0.08),
            midlineColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
            gaWeeksAt: (d) =>
                PregnancyMath.gaDays(profile, d) / 7.0,
          ),
        ),
      ),
    );
  }

  double _xFor(int i, double width) {
    const leftPad = 44.0, rightPad = 64.0;
    final t0 = points.first.date.millisecondsSinceEpoch;
    final t1 = points.last.date.millisecondsSinceEpoch;
    final span = math.max(1, t1 - t0);
    final f = (points[i].date.millisecondsSinceEpoch - t0) / span;
    return leftPad + f * (width - leftPad - rightPad);
  }
}

class _EfwChartPainter extends CustomPainter {
  final List<_ScanPoint> points;
  final List<String> labels;
  final double progress;
  final int? selected;
  final Color surface;
  final Color gridColor;
  final Color textColor;
  final Color bandColor;
  final Color midlineColor;
  final double Function(DateTime) gaWeeksAt;

  static const leftPad = 44.0, rightPad = 64.0, topPad = 12.0, bottomPad = 28.0;

  _EfwChartPainter({
    required this.points,
    required this.labels,
    required this.progress,
    required this.selected,
    required this.surface,
    required this.gridColor,
    required this.textColor,
    required this.bandColor,
    required this.midlineColor,
    required this.gaWeeksAt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      for (final p in points) ...p.efw.values,
    ];
    if (values.isEmpty) return;
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    // Widen bounds to keep the Hadlock reference band in frame across the
    // visible gestational span.
    final gaFirst = gaWeeksAt(points.first.date);
    final gaLast = gaWeeksAt(points.last.date);
    final refLo = efwPercentilesAt(gaFirst);
    final refHi = efwPercentilesAt(gaLast);
    if (refLo != null) minV = math.min(minV, refLo.p10);
    if (refHi != null) maxV = math.max(maxV, refHi.p90);
    if (minV == maxV) {
      minV -= 200;
      maxV += 200;
    }
    final pad = (maxV - minV) * 0.18;
    minV = math.max(0, (minV - pad) / 100).floorToDouble() * 100;
    maxV = ((maxV + pad) / 100).ceilToDouble() * 100;

    double yFor(double v) =>
        topPad +
        (1 - (v - minV) / (maxV - minV)) * (size.height - topPad - bottomPad);

    double xFor(int i) {
      final t0 = points.first.date.millisecondsSinceEpoch;
      final t1 = points.last.date.millisecondsSinceEpoch;
      final span = math.max(1, t1 - t0);
      final f = (points[i].date.millisecondsSinceEpoch - t0) / span;
      return leftPad + f * (size.width - leftPad - rightPad);
    }

    // Hadlock reference band (10th–90th) + dashed 50th, drawn FIRST so it
    // sits behind everything. Sampled across the plot width.
    if (points.length > 1) {
      const samples = 24;
      final upper = <Offset>[];
      final lower = <Offset>[];
      final mid = <Offset>[];
      final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
      final t1 = points.last.date.millisecondsSinceEpoch.toDouble();
      for (var s = 0; s <= samples; s++) {
        final f = s / samples;
        final t = t0 + (t1 - t0) * f;
        final date = DateTime.fromMillisecondsSinceEpoch(t.round());
        final ref = efwPercentilesAt(gaWeeksAt(date));
        if (ref == null) continue;
        final x = leftPad + f * (size.width - leftPad - rightPad);
        upper.add(Offset(x, yFor(ref.p90)));
        lower.add(Offset(x, yFor(ref.p10)));
        mid.add(Offset(x, yFor(ref.p50)));
      }
      if (upper.length > 1) {
        final band = Path()..moveTo(upper.first.dx, upper.first.dy);
        for (final o in upper.skip(1)) {
          band.lineTo(o.dx, o.dy);
        }
        for (final o in lower.reversed) {
          band.lineTo(o.dx, o.dy);
        }
        band.close();
        canvas.drawPath(band, Paint()..color = bandColor);
        // Dashed 50th-centile line.
        final dashPaint = Paint()
          ..color = midlineColor
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < mid.length - 1; i += 2) {
          canvas.drawLine(mid[i], mid[i + 1], dashPaint);
        }
        _text(canvas, '50th', Offset(upper.first.dx + 2, mid.first.dy - 14),
            9.5, midlineColor);
      }
    }

    // Recessive grid: 4 hairlines + muted value labels.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    const gridCount = 4;
    for (var g = 0; g <= gridCount; g++) {
      final v = minV + (maxV - minV) * g / gridCount;
      final y = yFor(v);
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
      _text(canvas, '${v.round()}', Offset(0, y - 6), 10, textColor,
          maxWidth: leftPad - 6);
    }

    // X labels: first and last scan dates (avoid collisions when dense).
    final fmt = DateFormat('d MMM');
    _text(canvas, fmt.format(points.first.date),
        Offset(leftPad - 12, size.height - 16), 10, textColor);
    if (points.length > 1) {
      _text(canvas, fmt.format(points.last.date),
          Offset(size.width - rightPad - 24, size.height - 16), 10, textColor);
    }

    // Selection column.
    if (selected != null && selected! < points.length) {
      final x = xFor(selected!);
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, size.height - bottomPad),
        Paint()
          ..color = textColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }

    for (final label in labels) {
      final color = babyColor(label);
      final series = <Offset>[];
      for (var i = 0; i < points.length; i++) {
        final v = points[i].efw[label];
        if (v != null) series.add(Offset(xFor(i), yFor(v)));
      }
      if (series.isEmpty) continue;

      // Animated draw-in via clip.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(
          0, 0, leftPad + (size.width - leftPad) * progress, size.height));

      if (series.length > 1) {
        final path = Path()..moveTo(series.first.dx, series.first.dy);
        for (final o in series.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }

      for (final o in series) {
        // 2px surface ring, then the 8px marker (shape = secondary encoding).
        if (label == 'B') {
          final ring = RRect.fromRectAndRadius(
              Rect.fromCenter(center: o, width: 12, height: 12),
              const Radius.circular(3.5));
          canvas.drawRRect(ring, Paint()..color = surface);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: o, width: 9, height: 9),
                const Radius.circular(2.5)),
            Paint()..color = color,
          );
        } else {
          canvas.drawCircle(o, 6.5, Paint()..color = surface);
          canvas.drawCircle(o, 4.5, Paint()..color = color);
        }
      }
      canvas.restore();

      // Direct end label (text in muted ink, swatch carries identity).
      if (progress > 0.95) {
        final end = series.last;
        _text(
            canvas,
            '${points.last.efw[label]?.round() ?? ''} g',
            Offset(end.dx + 10, end.dy - 6),
            11,
            textColor,
            bold: true);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color,
      {double? maxWidth, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: maxWidth ?? 100);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_EfwChartPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.points != points;
}
