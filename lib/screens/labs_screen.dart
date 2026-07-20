import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../store.dart';

class _LabPoint {
  final DateTime date;
  final num? value;
  final String? raw;
  final String? unit;
  final String? range;
  final String? flag;
  _LabPoint(this.date, this.value, this.raw, this.unit, this.range, this.flag);
}

/// Lab values across the whole pregnancy, grouped per test.
class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});

  Map<String, List<_LabPoint>> _series(AppStore store) {
    final byTest = <String, List<_LabPoint>>{};
    for (final r in store.records) {
      if (r.aiJson.isEmpty) continue;
      Map<String, dynamic> j;
      try {
        j = jsonDecode(r.aiJson) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      if (j['kind'] != 'lab') continue;
      DateTime date = r.date;
      if (j['report_date'] is String) {
        date = DateTime.tryParse(j['report_date'] as String) ?? date;
      }
      for (final t in ((j['tests'] ?? []) as List)) {
        final test = (t as Map).cast<String, dynamic>();
        final name = (test['name'] ?? '').toString();
        if (name.isEmpty) continue;
        byTest.putIfAbsent(name, () => []).add(_LabPoint(
              date,
              test['value'] as num?,
              test['value_raw'] as String?,
              test['unit'] as String?,
              test['reference_range'] as String?,
              test['flag'] as String?,
            ));
      }
    }
    for (final list in byTest.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
    return byTest;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final series = _series(store);
    final names = series.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Lab trends')),
      body: names.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bloodtype_outlined,
                        size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Read a blood report with AI ("Read a scan" → Lab report) and every value — Hb, sugar, TSH — starts trending here across your pregnancy.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: names.length,
              itemBuilder: (context, i) {
                final name = names[i];
                final points = series[name]!;
                final latest = points.last;
                num? prevValue;
                for (var k = points.length - 2; k >= 0; k--) {
                  if (points[k].value != null) {
                    prevValue = points[k].value;
                    break;
                  }
                }
                IconData? trend;
                if (latest.value != null && prevValue != null) {
                  trend = latest.value! > prevValue
                      ? Icons.arrow_upward
                      : latest.value! < prevValue
                          ? Icons.arrow_downward
                          : Icons.arrow_forward;
                }
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    shape: const Border(),
                    title: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${latest.value ?? latest.raw ?? '—'} ${latest.unit ?? ''}'
                      '${latest.flag != null ? ' (${latest.flag})' : ''}'
                      ' · ${DateFormat('d MMM').format(latest.date)}'
                      '${points.length > 1 ? ' · ${points.length} results' : ''}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: latest.flag != null
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: trend == null
                        ? null
                        : Icon(trend, size: 18, color: scheme.onSurfaceVariant),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      for (final pt in points.reversed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                    DateFormat('d MMM').format(pt.date),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant)),
                              ),
                              Expanded(
                                child: Text(
                                  '${pt.value ?? pt.raw ?? '—'} ${pt.unit ?? ''}'
                                  '${pt.flag != null ? '  (${pt.flag})' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: pt.flag != null
                                        ? scheme.error
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(pt.range ?? '',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Ranges shown are the ones printed on each report. Interpretation belongs to your doctor.',
                          style: TextStyle(
                              fontSize: 11, color: scheme.outline),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
