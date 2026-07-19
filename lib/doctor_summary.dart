import 'dart:convert';

import 'package:intl/intl.dart';

import 'models.dart';
import 'pregnancy_math.dart';
import 'store.dart';

/// Plain-text summary of the pregnancy for sharing with the care team
/// (WhatsApp/print/email via the system share sheet).
String buildDoctorSummary(AppStore store) {
  final p = store.profile;
  if (p == null) return 'No pregnancy profile set up yet.';
  final fmt = DateFormat('d MMM yyyy');
  final b = StringBuffer();

  b.writeln('BumpBuddy summary — ${fmt.format(DateTime.now())}');
  b.writeln('');
  b.writeln(
      '${p.isTwins ? 'Twin pregnancy (${p.chorionicity?.shortName ?? 'chorionicity not set'})' : 'Singleton pregnancy'}${p.ivf ? ' · IVF' : ''}');
  if (p.delivered) {
    b.writeln(
        'Delivered${p.deliveredAt != null ? ' on ${fmt.format(p.deliveredAt!)}' : ''} 🎉');
  } else {
    b.writeln(
        'Gestational age: ${PregnancyMath.gaLabel(p)} · EDD ${fmt.format(p.edd)}');
  }
  if (p.doctorName.isNotEmpty || p.hospitalName.isNotEmpty) {
    b.writeln([
      if (p.doctorName.isNotEmpty) p.doctorName,
      if (p.hospitalName.isNotEmpty) p.hospitalName,
    ].join(' · '));
  }

  // Latest AI-read scan.
  final scans = store.records
      .where((r) =>
          r.category == RecordCategory.ultrasound && r.aiJson.isNotEmpty)
      .toList()
    ..sort((a, b2) => b2.date.compareTo(a.date));
  if (scans.isNotEmpty) {
    try {
      final j = jsonDecode(scans.first.aiJson) as Map<String, dynamic>;
      b.writeln('');
      b.writeln(
          'Latest scan (${j['report_date'] ?? fmt.format(scans.first.date)}'
          '${j['gestational_age_on_report'] != null ? ', ${j['gestational_age_on_report']}' : ''}):');
      for (final baby
          in ((j['babies'] ?? []) as List).cast<Map<String, dynamic>>()) {
        final label = baby['label'];
        final nick = p.babies
            .firstWhere((x) => x.label == label,
                orElse: () => Baby(label: (label ?? '?') as String))
            .displayName;
        final parts = <String>[
          if (baby['efw_grams'] != null) 'EFW ${baby['efw_grams']} g',
          if (baby['presentation'] != null) '${baby['presentation']}',
          if (baby['fhr_bpm'] != null) 'FHR ${baby['fhr_bpm']}',
          if (baby['placenta_grade'] != null) '${baby['placenta_grade']}',
          if (baby['dvp_cm'] != null) 'DVP ${baby['dvp_cm']} cm',
          if (baby['liquor_afi_cm'] != null) 'AFI ${baby['liquor_afi_cm']} cm',
        ];
        if (parts.isNotEmpty) b.writeln('  $nick: ${parts.join(', ')}');
      }
      final derived = (j['derived'] ?? {}) as Map<String, dynamic>;
      final disc = derived['efw_discordance_percent'] ??
          j['printed_efw_discordance_percent'];
      if (disc != null) b.writeln('  EFW discordance: $disc%');
    } catch (_) {}
  }

  if (store.weights.isNotEmpty) {
    final latest = store.weights.last;
    final delta = store.weights.length >= 2
        ? latest.kg - store.weights.first.kg
        : null;
    b.writeln('');
    b.writeln(
        'Weight: ${latest.kg.toStringAsFixed(1)} kg (${fmt.format(latest.date)})'
        '${delta != null ? ' · ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg overall' : ''}');
  }

  if (store.bpEntries.isNotEmpty) {
    b.writeln('Recent BP:');
    for (final e in store.bpEntries.take(3)) {
      b.writeln(
          '  ${e.systolic}/${e.diastolic} (${DateFormat('d MMM h:mm a').format(e.dateTime)})${e.isHigh ? ' ⚠' : ''}');
    }
  }

  final meds = store.medicines.where((m) => m.active).toList();
  if (meds.isNotEmpty) {
    b.writeln('');
    b.writeln('Medicines:');
    for (final m in meds) {
      b.writeln(
          '  ${m.name}${m.dose.isEmpty ? '' : ' ${m.dose}'} — ${m.slots.join('/')}');
    }
  }

  final next = store.nextAppointment;
  if (next != null) {
    b.writeln('');
    b.writeln(
        'Next appointment: ${next.title} — ${DateFormat('EEE d MMM, h:mm a').format(next.dateTime)}');
  }

  final recentSymptoms = store.symptoms.take(3).toList();
  if (recentSymptoms.isNotEmpty) {
    b.writeln('');
    b.writeln('Recent symptoms:');
    for (final s in recentSymptoms) {
      b.writeln(
          '  ${s.symptom} (${s.severity}/5, ${DateFormat('d MMM').format(s.date)})${s.doctorInformed ? ' — doctor informed' : ''}');
    }
  }

  b.writeln('');
  b.writeln('Shared from BumpBuddy — data as entered/AI-read by the user.');
  return b.toString();
}
