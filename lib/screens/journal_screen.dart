import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom journal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Log symptom'),
      ),
      body: store.symptoms.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Log symptoms with severity and duration.\nPatterns become easy to show your doctor.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: store.symptoms.length,
              itemBuilder: (context, i) {
                final s = store.symptoms[i];
                final week = PregnancyMath.gaWeeks(store.profile!, s.date);
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _openEditor(context, existing: s),
                    leading: CircleAvatar(
                      backgroundColor: _severityColor(context, s.severity),
                      child: Text('${s.severity}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    title: Text(s.symptom),
                    subtitle: Text([
                      '${DateFormat('d MMM').format(s.date)} · week $week',
                      if (s.duration.isNotEmpty) s.duration,
                      if (s.medicineTaken.isNotEmpty) 'took ${s.medicineTaken}',
                      if (s.doctorInformed) 'doctor informed ✓',
                    ].join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.deleteSymptom(s.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _severityColor(BuildContext context, int severity) {
    return switch (severity) {
      <= 2 => Colors.green.shade400,
      3 => Colors.orange.shade400,
      _ => Colors.red.shade400,
    };
  }

  void _openEditor(BuildContext context, {SymptomEntry? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SymptomEditor(existing: existing),
    );
  }
}

class _SymptomEditor extends StatefulWidget {
  final SymptomEntry? existing;
  const _SymptomEditor({this.existing});

  @override
  State<_SymptomEditor> createState() => _SymptomEditorState();
}

class _SymptomEditorState extends State<_SymptomEditor> {
  static const quickSymptoms = [
    'Nausea', 'Headache', 'Back pain', 'Heartburn', 'Fatigue',
    'Swelling', 'Cramping', 'Dizziness', 'Spotting', 'Constipation',
  ];

  late final TextEditingController _symptom;
  late final TextEditingController _duration;
  late final TextEditingController _medicine;
  late final TextEditingController _notes;
  late DateTime _date;
  late int _severity;
  late bool _doctorInformed;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _symptom = TextEditingController(text: e?.symptom ?? '');
    _duration = TextEditingController(text: e?.duration ?? '');
    _medicine = TextEditingController(text: e?.medicineTaken ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _date = e?.date ?? DateTime.now();
    _severity = e?.severity ?? 2;
    _doctorInformed = e?.doctorInformed ?? false;
    _symptom.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _symptom.dispose();
    _duration.dispose();
    _medicine.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'Log a symptom' : 'Edit symptom',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in quickSymptoms)
                  ChoiceChip(
                    label: Text(q),
                    selected: _symptom.text == q,
                    onSelected: (_) => setState(() => _symptom.text = q),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _symptom,
              decoration: const InputDecoration(labelText: 'Symptom'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Severity'),
                Expanded(
                  child: Slider(
                    value: _severity.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_severity',
                    onChanged: (v) => setState(() => _severity = v.round()),
                  ),
                ),
                Text('$_severity/5'),
              ],
            ),
            TextField(
              controller: _duration,
              decoration: const InputDecoration(
                  labelText: 'Duration', hintText: 'e.g. 2 hours, all morning'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _medicine,
              decoration: const InputDecoration(
                  labelText: 'Medicine taken (if any)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Doctor informed'),
              value: _doctorInformed,
              onChanged: (v) => setState(() => _doctorInformed = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 280)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _symptom.text.trim().isEmpty
                    ? null
                    : () {
                        store.upsertSymptom(SymptomEntry(
                          id: widget.existing?.id ?? store.newId(),
                          date: _date,
                          symptom: _symptom.text.trim(),
                          severity: _severity,
                          duration: _duration.text.trim(),
                          medicineTaken: _medicine.text.trim(),
                          doctorInformed: _doctorInformed,
                          notes: _notes.text.trim(),
                        ));
                        Navigator.pop(context);
                      },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
