import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../doctor_summary.dart';
import '../models.dart';
import '../notification_service.dart';
import '../store.dart';
import '../weekly_content.dart';
import 'ai_settings_screen.dart';
import 'appointments_screen.dart';
import 'bp_screen.dart';
import 'chat_screen.dart';
import 'contraction_timer_screen.dart';
import 'edit_profile_screen.dart';
import 'growth_screen.dart';
import 'hospital_bag_screen.dart';
import 'kick_counter_screen.dart';
import 'labs_screen.dart';
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
          _navTile(context, Icons.show_chart, 'Growth',
              'Scan-over-scan weight curves', const GrowthScreen()),
          _navTile(context, Icons.timer_outlined, 'Contraction timer',
              '5-1-1 pattern awareness for labour', const ContractionTimerScreen()),
          _navTile(context, Icons.favorite_outline, 'Blood pressure',
              'Home & clinic readings, high-reading flags', const BpScreen()),
          _navTile(context, Icons.chat_bubble_outline, 'Ask BumpBuddy',
              'AI chat grounded in your own data', const ChatScreen()),
          _navTile(context, Icons.bloodtype_outlined, 'Lab trends',
              'Hb, sugar, TSH — every value over time', const LabsScreen()),
          _navTile(context, Icons.auto_awesome_outlined, 'AI scan reading',
              'Connect your Azure AI deployment', const AiSettingsScreen()),
          SwitchListTile(
            secondary: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.notifications_active_outlined,
                  color: scheme.primary),
            ),
            title: const Text('Daily kick reminder'),
            subtitle: const Text('8 pm, from week 28'),
            value: store.kickReminderEnabled,
            onChanged: (v) async {
              await store.setKickReminder(v);
              await NotificationService.instance.syncKickReminder(p, v);
            },
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.surfaceContainerHigh,
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.ios_share, color: scheme.primary),
                  ),
                  title: const Text('Share doctor summary'),
                  subtitle: const Text(
                      'Latest scan, weight, BP & meds as text'),
                  onTap: () =>
                      SharePlus.instance.share(ShareParams(
                          text: buildDoctorSummary(store),
                          subject: 'Pregnancy summary')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.backup_outlined, color: scheme.primary),
                  ),
                  title: const Text('Export backup'),
                  subtitle: const Text(
                      'All data as a file — keep it somewhere safe'),
                  onTap: () async {
                    final json = const JsonEncoder.withIndent('  ')
                        .convert(store.exportAll());
                    await SharePlus.instance.share(ShareParams(files: [
                      XFile.fromData(
                        Uint8List.fromList(utf8.encode(json)),
                        name:
                            'bumpbuddy-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
                        mimeType: 'application/json',
                      ),
                    ]));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.restore, color: scheme.primary),
                  ),
                  title: const Text('Restore backup'),
                  subtitle:
                      const Text('Replaces everything with a backup file'),
                  onTap: () => _restoreBackup(context, store),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!p.delivered)
            Card(
              color: scheme.tertiaryContainer,
              child: ListTile(
                leading: const Text('🎉', style: TextStyle(fontSize: 24)),
                title: Text(
                    p.isTwins ? 'The babies have arrived!' : 'Baby has arrived!',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: scheme.onTertiaryContainer)),
                subtitle: Text('Tap to switch off pregnancy reminders',
                    style: TextStyle(color: scheme.onTertiaryContainer)),
                onTap: () => _markDelivered(context, store, p),
              ),
            )
          else
            Card(
              color: scheme.surfaceContainerHigh,
              child: ListTile(
                leading: const Text('🎉', style: TextStyle(fontSize: 24)),
                title: Text(
                    'Delivered${p.deliveredAt != null ? ' on ${DateFormat('d MMM yyyy').format(p.deliveredAt!)}' : ''}'),
                subtitle: const Text('Records and growth history stay available'),
                trailing: TextButton(
                  onPressed: () async {
                    p.delivered = false;
                    p.deliveredAt = null;
                    await store.saveProfile(p);
                    await NotificationService.instance
                        .syncMedicines(store.medicines);
                    await NotificationService.instance
                        .syncAppointments(store.appointments);
                  },
                  child: const Text('Undo'),
                ),
              ),
            ),
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

  Future<void> _restoreBackup(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    const group = XTypeGroup(
        label: 'BumpBuddy backup',
        extensions: ['json'],
        mimeTypes: ['application/json']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text(
            'Everything currently in the app will be REPLACED by the backup. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace everything')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await store.importAll(data);
      messenger.showSnackBar(
          const SnackBar(content: Text('Backup restored.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not restore: $e')));
    }
  }

  Future<void> _markDelivered(
      BuildContext context, AppStore store, PregnancyProfile p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.isTwins ? 'Babies have arrived? 🎉' : 'Baby has arrived? 🎉'),
        content: const Text(
            'Congratulations! This stops medicine, appointment and kick reminders. '
            'All your records, growth charts and history stay right here.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes! 🎉')),
        ],
      ),
    );
    if (confirmed != true) return;
    p.delivered = true;
    p.deliveredAt = DateTime.now();
    await store.saveProfile(p);
    await NotificationService.instance.cancelAll();
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
