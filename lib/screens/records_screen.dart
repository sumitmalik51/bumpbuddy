import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ai/ai_config.dart';
import '../ai/scan_reader.dart';
import '../attachments.dart';
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
                          leading: (!kIsWeb &&
                                  r.hasAttachment &&
                                  r.isImageAttachment)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(r.filePath),
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

class _AiResultSummary extends StatelessWidget {
  final String aiJson;
  const _AiResultSummary({required this.aiJson});

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
              style:
                  TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
        ],
      ),
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
  late String _fileName;
  late String _filePath;
  late String _aiJson;
  bool _aiRunning = false;
  late final String _recordId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? RecordCategory.ultrasound;
    _date = e?.date ?? DateTime.now();
    _fileName = e?.fileName ?? '';
    _filePath = e?.filePath ?? '';
    _aiJson = e?.aiJson ?? '';
    _recordId = e?.id ?? context.read<AppStore>().newId();
    _title.addListener(() => setState(() {}));
  }

  static bool _isImagePath(String p) {
    final n = p.toLowerCase();
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp');
  }

  Future<void> _readWithAi() async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final config = await AiConfigStore.load();
    if (!config.isComplete) {
      messenger.showSnackBar(const SnackBar(
        content:
            Text('Set up your Azure connection first: More → AI scan reading'),
      ));
      return;
    }
    setState(() => _aiRunning = true);
    try {
      final result = await ScanReader.extract(
        config: config,
        image: File(_filePath),
        twinsHint: store.profile?.isTwins ?? false,
      );
      if (!mounted) return;
      setState(() {
        _aiJson = jsonEncode(result);
        _aiRunning = false;
      });
      messenger.showSnackBar(const SnackBar(
          content: Text('Scan read — review the values below, then Save.')));
    } on ScanReaderException catch (e) {
      if (!mounted) return;
      setState(() => _aiRunning = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiRunning = false);
      messenger.showSnackBar(SnackBar(content: Text('AI reading failed: $e')));
    }
  }

  Future<void> _attach(
      Future<({String fileName, String filePath})?> Function(String) pick)
      async {
    final result = await pick(_recordId);
    if (result != null && mounted) {
      // Replace any previous copy.
      if (_filePath.isNotEmpty && _filePath != result.filePath) {
        await Attachments.delete(_filePath);
      }
      setState(() {
        _fileName = result.fileName;
        _filePath = result.filePath;
        if (_title.text.trim().isEmpty) {
          _title.text = result.fileName;
        }
      });
    }
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
                      label: const Text('File'),
                    ),
                  ),
                ],
              ),
              if (_filePath.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(_fileName.isEmpty ? 'Attachment' : _fileName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Tap to open'),
                  onTap: () => Attachments.open(_filePath),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove attachment',
                    onPressed: () async {
                      await Attachments.delete(_filePath);
                      if (mounted) {
                        setState(() {
                          _filePath = '';
                          _fileName = '';
                        });
                      }
                    },
                  ),
                ),
              if (_filePath.isNotEmpty &&
                  _category == RecordCategory.ultrasound &&
                  _isImagePath(_filePath)) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _aiRunning ? null : _readWithAi,
                    icon: _aiRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_aiRunning
                        ? 'Reading scan… (can take a minute)'
                        : (_aiJson.isEmpty
                            ? 'Read with AI'
                            : 'Re-read with AI')),
                  ),
                ),
                if (_aiJson.isNotEmpty)
                  _AiResultSummary(aiJson: _aiJson),
              ],
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
                          fileName: _fileName,
                          filePath: _filePath,
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
