import 'dart:convert';

import 'package:flutter/material.dart';

/// Renders a saved scan-reader extraction (per-baby values, twin weight
/// difference with the 20% guardrail note, and the model's honesty notes).
class AiResultSummary extends StatelessWidget {
  final String aiJson;
  const AiResultSummary({super.key, required this.aiJson});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Map<String, dynamic> r;
    try {
      r = jsonDecode(aiJson) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final babies =
        ((r['babies'] ?? []) as List).cast<Map<String, dynamic>>();
    final derived = (r['derived'] ?? {}) as Map<String, dynamic>;
    // Prefer our own computed discordance; fall back to the value the
    // report itself prints when we could not compute one.
    final computed = derived['efw_discordance_percent'];
    final printed = r['printed_efw_discordance_percent'];
    final pct = computed ?? printed;
    final significant = computed != null
        ? derived['efw_discordance_clinically_significant'] == true
        : (printed is num && printed >= 20);

    String fmt(dynamic v, String unit) => v == null ? '—' : '$v $unit';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'AI reading · ${r['gestational_age_on_report'] ?? r['report_date'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final b in babies) ...[
            Text('Baby ${b['label']}'
                '${b['presentation'] != null ? ' · ${b['presentation']}' : ''}',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: scheme.primary)),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 6),
              child: Text(
                'EFW ${fmt(b['efw_grams'], 'g')} · HC ${fmt(b['hc_mm'], 'mm')} · '
                'AC ${fmt(b['ac_mm'], 'mm')} · FL ${fmt(b['fl_mm'], 'mm')} · '
                'FHR ${fmt(b['fhr_bpm'], 'bpm')}\n'
                'Placenta: ${b['placenta'] ?? '—'}'
                '${b['placenta_grade'] != null ? ' (${b['placenta_grade']})' : ''} · '
                'Fluid: ${b['liquor_afi_cm'] != null ? 'AFI ${b['liquor_afi_cm']} cm' : b['dvp_cm'] != null ? 'DVP ${b['dvp_cm']} cm' : '—'}',
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
          if (pct != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: significant
                    ? scheme.errorContainer
                    : scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Twin weight difference: $pct%'
                '${significant ? ' — worth discussing with your doctor' : ' (below the 20% attention level)'}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: significant
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
            ),
          if (r['confidence_notes'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Note: ${r['confidence_notes']}',
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Extracted from the report photo — verify against the original. Not medical advice.',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
