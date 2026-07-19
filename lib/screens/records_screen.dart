import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  RecordCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final items = _filter == null
        ? store.records
        : store.records.where((r) => r.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Records vault')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add record'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final c in RecordCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(c.label),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: scheme.outline),
                          const SizedBox(height: 16),
                          const Text(
                            'Keep every scan, report and prescription organized in one place.\n\nAI reading of scans arrives in the next version — the vault is ready for it.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final r = items[i];
                      return Card(
                        color: scheme.surfaceContainerHigh,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _openEditor(context, existing: r),
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(_iconFor(r.category), color: scheme.primary),
                          ),
                          title: Text(r.title),
                          subtitle: Text([
                            '${r.category.label} · ${DateFormat('d MMM yyyy').format(r.date)}',
                            if (r.fileName.isNotEmpty) r.fileName,
                            if (r.notes.isNotEmpty) r.notes,
                          ].join('\n')),
                          isThreeLine: r.fileName.isNotEmpty || r.notes.isNotEmpty,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => store.deleteRecord(r.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(RecordCategory c) => switch (c) {
        RecordCategory.ultrasound => Icons.monitor_heart_outlined,
        RecordCategory.bloodTest => Icons.bloodtype_outlined,
        RecordCategory.prescription => Icons.receipt_long_outlined,
        RecordCategory.vaccination => Icons.vaccines_outlined,
        RecordCategory.bill => Icons.currency_rupee,
        RecordCategory.photo => Icons.photo_outlined,
        RecordCategory.other => Icons.description_outlined,
      };

  void _openEditor(BuildContext context, {RecordItem? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecordEditor(existing: existing),
    );
  }
}

class _RecordEditor extends StatefulWidget {
  final RecordItem? existing;
  const _RecordEditor({this.existing});

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late RecordCategory _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? RecordCategory.ultrasound;
    _date = e?.date ?? DateTime.now();
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
            Text(widget.existing == null ? 'Add a record' : 'Edit record',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in RecordCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Anomaly scan — Apollo Diagnostics'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'e.g. Both babies normal, next scan in 2 weeks'),
              maxLines: 2,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 310)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            Text(
              'File attachments (photos/PDFs) arrive with the mobile build.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _title.text.trim().isEmpty
                    ? null
                    : () {
                        store.upsertRecord(RecordItem(
                          id: widget.existing?.id ?? store.newId(),
                          date: _date,
                          category: _category,
                          title: _title.text.trim(),
                          notes: _notes.text.trim(),
                          fileName: widget.existing?.fileName ?? '',
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
