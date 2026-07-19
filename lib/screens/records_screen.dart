import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../attachments.dart';
import '../models.dart';
import '../store.dart';
import 'scan_read_screen.dart';
import 'widgets/ai_result_summary.dart';

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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (Attachments.supported)
            FloatingActionButton.extended(
              heroTag: 'scan',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanReadScreen())),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Read a scan'),
            ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Add record'),
          ),
        ],
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
                          Icon(Icons.folder_open,
                              size: 64, color: scheme.outline),
                          const SizedBox(height: 16),
                          const Text(
                            'Keep every scan, report and prescription in one place.\n\nTap "Read a scan" to photograph a report and let AI fill in the details.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final r = items[i];
                      final thumb = r.imageAttachments.isNotEmpty
                          ? r.imageAttachments.first
                          : null;
                      return Card(
                        color: scheme.surfaceContainerHigh,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _openEditor(context, existing: r),
                          leading: (!kIsWeb && thumb != null)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(thumb.filePath),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => CircleAvatar(
                                      backgroundColor: scheme.primaryContainer,
                                      child: Icon(_iconFor(r.category),
                                          color: scheme.primary),
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  child: Icon(_iconFor(r.category),
                                      color: scheme.primary),
                                ),
                          title: Text(r.title),
                          subtitle: Text([
                            '${r.category.label} · ${DateFormat('d MMM yyyy').format(r.date)}'
                                '${r.aiJson.isNotEmpty ? ' · ✦ AI read' : ''}',
                            if (r.attachments.isNotEmpty)
                              r.attachments.length == 1
                                  ? r.attachments.first.fileName
                                  : '${r.attachments.length} pages',
                            if (r.notes.isNotEmpty) r.notes,
                          ].join('\n')),
                          isThreeLine:
                              r.attachments.isNotEmpty || r.notes.isNotEmpty,
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
  late List<RecordAttachment> _attachments;
  late String _aiJson;
  late final String _recordId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? RecordCategory.ultrasound;
    _date = e?.date ?? DateTime.now();
    _attachments = List.of(e?.attachments ?? const []);
    _aiJson = e?.aiJson ?? '';
    _recordId = e?.id ?? context.read<AppStore>().newId();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _attach(
      Future<List<({String fileName, String filePath})>> Function(String)
          pick) async {
    final results = await pick(_recordId);
    if (results.isEmpty || !mounted) return;
    setState(() {
      _attachments.addAll(results
          .map((r) =>
              RecordAttachment(fileName: r.fileName, filePath: r.filePath)));
      if (_title.text.trim().isEmpty) {
        _title.text = results.first.fileName;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final scheme = Theme.of(context).colorScheme;
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
            if (Attachments.supported) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _attach(Attachments.fromCamera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _attach(Attachments.fromGallery),
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _attach(Attachments.fromFiles),
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Files'),
                    ),
                  ),
                ],
              ),
              if (_attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final a = _attachments[i];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => Attachments.open(a.filePath),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: a.isImage && !kIsWeb
                                    ? Image.file(File(a.filePath),
                                        width: 68,
                                        height: 68,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 68,
                                        height: 68,
                                        color:
                                            scheme.surfaceContainerHighest,
                                        child: const Icon(
                                            Icons.description_outlined),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  await Attachments.delete(a.filePath);
                                  if (mounted) {
                                    setState(() => _attachments.removeAt(i));
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: scheme.inverseSurface,
                                  child: Icon(Icons.close,
                                      size: 12,
                                      color: scheme.onInverseSurface),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (_aiJson.isNotEmpty) AiResultSummary(aiJson: _aiJson),
            ] else
              Text(
                'Photo/PDF attachments work in the mobile app.',
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
                          id: _recordId,
                          date: _date,
                          category: _category,
                          title: _title.text.trim(),
                          notes: _notes.text.trim(),
                          attachments: _attachments,
                          aiJson: _aiJson,
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
