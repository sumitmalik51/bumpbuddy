import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final upcoming = store.appointments
        .where((a) => !a.done && a.dateTime.isAfter(now.subtract(const Duration(hours: 12))))
        .toList();
    final past = store.appointments.where((a) => !upcoming.contains(a)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: store.appointments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined, size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Track doctor visits, scans and tests.\nThe next one shows on your home screen.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (upcoming.isNotEmpty) ...[
                  Text('Upcoming', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final a in upcoming) _tile(context, store, a),
                  const SizedBox(height: 16),
                ],
                if (past.isNotEmpty) ...[
                  Text('Past / done', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final a in past) _tile(context, store, a),
                ],
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, AppStore store, Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openEditor(context, existing: a),
        leading: Checkbox(
          value: a.done,
          onChanged: (v) {
            a.done = v ?? false;
            store.upsertAppointment(a);
          },
        ),
        title: Text(a.title,
            style: a.done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null),
        subtitle: Text(
            '${DateFormat('EEE, d MMM yyyy').format(a.dateTime)} · ${DateFormat('h:mm a').format(a.dateTime)} · ${a.type.label}${a.notes.isEmpty ? '' : '\n${a.notes}'}'),
        isThreeLine: a.notes.isNotEmpty,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => store.deleteAppointment(a.id),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {Appointment? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AppointmentEditor(existing: existing),
    );
  }
}

class _AppointmentEditor extends StatefulWidget {
  final Appointment? existing;
  const _AppointmentEditor({this.existing});

  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late AppointmentType _type;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _type = e?.type ?? AppointmentType.doctorVisit;
    final dt = e?.dateTime ?? DateTime.now().add(const Duration(days: 1));
    _date = DateTime(dt.year, dt.month, dt.day);
    _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
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
            Text(widget.existing == null ? 'Add appointment' : 'Edit appointment',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in AppointmentType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title', hintText: 'e.g. Growth scan + Dr. review'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormat('d MMM yyyy').format(_date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now().subtract(const Duration(days: 310)),
                        lastDate: DateTime.now().add(const Duration(days: 310)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(_time.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                          context: context, initialTime: _time);
                      if (picked != null) setState(() => _time = picked);
                    },
                  ),
                ),
              ],
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. carry OGTT report, fasting required'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _title.text.trim().isEmpty
                    ? null
                    : () {
                        store.upsertAppointment(Appointment(
                          id: widget.existing?.id ?? store.newId(),
                          dateTime: DateTime(_date.year, _date.month, _date.day,
                              _time.hour, _time.minute),
                          title: _title.text.trim(),
                          type: _type,
                          notes: _notes.text.trim(),
                          done: widget.existing?.done ?? false,
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
