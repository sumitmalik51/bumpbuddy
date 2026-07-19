import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../weekly_content.dart';
import 'appointments_screen.dart';
import 'edit_profile_screen.dart';
import 'hospital_bag_screen.dart';
import 'kick_counter_screen.dart';
import 'medicines_screen.dart';
import 'weight_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
                        child: Icon(
                            p.isTwins ? Icons.people_alt : Icons.child_care,
                            color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.isTwins
                                  ? 'Twins — ${p.babies.map((b) => b.displayName).join(' & ')}'
                                  : p.babies.first.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'EDD ${DateFormat('d MMM yyyy').format(p.edd)}'
                              '${p.isTwins && p.chorionicity != null ? ' · ${p.chorionicity!.shortName}' : ''}'
                              '${p.ivf ? ' · IVF' : ''}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant),
                            ),
                            if (p.doctorName.isNotEmpty ||
                                p.hospitalName.isNotEmpty)
                              Text(
                                [
                                  if (p.doctorName.isNotEmpty) p.doctorName,
                                  if (p.hospitalName.isNotEmpty) p.hospitalName,
                                ].join(' · '),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit profile',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()),
                        ),
                      ),
                    ],
                  ),
                  if (p.isTwins &&
                      (p.chorionicity == null ||
                          p.chorionicity == Chorionicity.unknown)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set your twins\' chorionicity',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.onTertiaryContainer),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'It\'s on your first-trimester scan report (DCDA / MCDA / MCMA). The timeline and scan schedule adapt to it.',
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onTertiaryContainer),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final c in [
                                Chorionicity.dcda,
                                Chorionicity.mcda,
                                Chorionicity.mcma
                              ])
                                ActionChip(
                                  label: Text(c.shortName),
                                  onPressed: () {
                                    p.chorionicity = c;
                                    store.saveProfile(p);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _navTile(context, Icons.medication_outlined, 'Medicines',
              'Daily supplements & prescriptions', const MedicinesScreen()),
          _navTile(context, Icons.event_outlined, 'Appointments',
              'Visits, scans & tests', const AppointmentsScreen()),
          _navTile(context, Icons.luggage_outlined, 'Hospital bag',
              p.isTwins ? 'Twin-ready checklist' : 'Packing checklist',
              const HospitalBagScreen()),
          _navTile(context, Icons.monitor_weight_outlined, 'Weight tracker',
              'Your weight over the weeks', const WeightScreen()),
          _navTile(
              context,
              Icons.touch_app_outlined,
              'Kick counter',
              p.isTwins ? 'Count to 10 — per baby' : 'Count to 10 sessions',
              const KickCounterScreen()),
          const SizedBox(height: 16),
          Card(
            color: scheme.errorContainer,
            child: ExpansionTile(
              leading: Icon(Icons.emergency_outlined,
                  color: scheme.onErrorContainer),
              title: Text('When to call the doctor now',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onErrorContainer)),
              iconColor: scheme.onErrorContainer,
              collapsedIconColor: scheme.onErrorContainer,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final w in WeeklyContent.warningSigns)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ',
                            style: TextStyle(color: scheme.onErrorContainer)),
                        Expanded(
                          child: Text(w,
                              style:
                                  TextStyle(color: scheme.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'BumpBuddy organizes your pregnancy — it does not diagnose, treat, or replace medical advice. '
                    'All schedules and week-by-week notes are typical patterns for education; your doctor\'s plan always takes precedence. '
                    'Your data stays on this device.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => _confirmReset(context, store),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Reset all data'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String title,
      String subtitle, Widget screen) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => screen)),
      ),
    );
  }

  void _confirmReset(BuildContext context, AppStore store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
            'This deletes the pregnancy profile, journal, records and all trackers from this device. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              store.resetAll();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
