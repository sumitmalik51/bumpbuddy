import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';

class BpScreen extends StatelessWidget {
  const BpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final entries = store.bpEntries;

    return Scaffold(
      appBar: AppBar(title: const Text('Blood pressure')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bp_fab',
        onPressed: () => _addEntry(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Log BP'),
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border,
                        size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Log readings from home checks or clinic visits.\n\nDoctors watch blood pressure closely in twin pregnancies — rising readings are worth flagging early.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                final color = e.isVeryHigh
                    ? scheme.error
                    : e.isHigh
                        ? Colors.orange
                        : scheme.primary;
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(Icons.favorite, color: color, size: 20),
                    ),
                    title: Text('${e.systolic} / ${e.diastolic} mmHg',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      DateFormat('EEE d MMM, h:mm a').format(e.dateTime),
                      if (e.isVeryHigh)
                        '⚠ Very high — contact your care team today'
                      else if (e.isHigh)
                        'Above 140/90 — mention this to your doctor',
                      if (e.note.isNotEmpty) e.note,
                    ].join('\n')),
                    isThreeLine: e.isHigh || e.note.isNotEmpty,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.deleteBp(e.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _addEntry(BuildContext context, AppStore store) {
    final sys = TextEditingController();
    final dia = TextEditingController();
    final note = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log blood pressure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sys,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Systolic', hintText: '120'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('/', style: TextStyle(fontSize: 24)),
                ),
                Expanded(
                  child: TextField(
                    controller: dia,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Diastolic', hintText: '80'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. after resting, left arm'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final s = int.tryParse(sys.text.trim());
              final d = int.tryParse(dia.text.trim());
              if (s != null && d != null && s > 50 && s < 260 && d > 30 && d < 200) {
                store.addBp(BpEntry(
                  id: store.newId(),
                  dateTime: DateTime.now(),
                  systolic: s,
                  diastolic: d,
                  note: note.text.trim(),
                ));
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
