import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ai/ai_config.dart';
import '../ai/lab_reader.dart';
import '../ai/scan_reader.dart';
import '../attachments.dart';
import '../models.dart';
import '../store.dart';
import 'ai_settings_screen.dart';
import 'widgets/ai_result_summary.dart';

/// The one-tap scan flow: photograph the report pages -> Read -> review ->
/// saved to Records automatically (and into the Growth chart).
class ScanReadScreen extends StatefulWidget {
  const ScanReadScreen({super.key});

  @override
  State<ScanReadScreen> createState() => _ScanReadScreenState();
}

class _ScanReadScreenState extends State<ScanReadScreen> {
  late final String _recordId;
  final List<RecordAttachment> _pages = [];
  bool _reading = false;
  bool _isLab = false;
  String? _aiJson;
  AiConfig? _config;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _recordId = context.read<AppStore>().newId();
    AiConfigStore.load().then((c) {
      if (mounted) {
        setState(() {
          _config = c;
          _configLoaded = true;
        });
      }
    });
  }

  Future<void> _add(
      Future<List<({String fileName, String filePath})>> Function(String)
          pick) async {
    final results = await pick(_recordId);
    if (results.isEmpty || !mounted) return;
    setState(() {
      _pages.addAll(results
          .where((r) => r.filePath.toLowerCase().endsWith('.jpg') ||
              r.filePath.toLowerCase().endsWith('.jpeg') ||
              r.filePath.toLowerCase().endsWith('.png') ||
              r.filePath.toLowerCase().endsWith('.webp'))
          .map((r) =>
              RecordAttachment(fileName: r.fileName, filePath: r.filePath)));
    });
  }

  Future<void> _read() async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reading = true);
    try {
      final files = _pages.map((p) => File(p.filePath)).toList();
      final result = _isLab
          ? await LabReader.extract(config: _config!, images: files)
          : await ScanReader.extract(
              config: _config!,
              images: files,
              twinsHint: store.profile?.isTwins ?? false,
            );
      if (!mounted) return;
      setState(() {
        _aiJson = jsonEncode(result);
        _reading = false;
      });
    } on ScanReaderException catch (e) {
      if (!mounted) return;
      setState(() => _reading = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _reading = false);
      messenger.showSnackBar(SnackBar(content: Text('Reading failed: $e')));
    }
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final r = jsonDecode(_aiJson!) as Map<String, dynamic>;
    var date = DateTime.now();
    if (r['report_date'] is String) {
      date = DateTime.tryParse(r['report_date'] as String) ?? date;
    }
    final ga = r['gestational_age_on_report'];
    final labName = r['lab_name'];
    await store.upsertRecord(RecordItem(
      id: _recordId,
      date: date,
      category: _isLab ? RecordCategory.bloodTest : RecordCategory.ultrasound,
      title: _isLab
          ? 'Lab report — ${labName ?? DateFormat('d MMM').format(date)}'
          : 'Growth scan${ga != null ? ' — $ga' : ' — ${DateFormat('d MMM').format(date)}'}',
      attachments: _pages,
      aiJson: _aiJson!,
    ));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Saved — see it in Records and on the Growth chart.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final configured = _config?.isComplete ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Read a scan')),
      body: !_configLoaded
          ? const Center(child: CircularProgressIndicator())
          : !configured
              ? _setupNudge(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: false,
                            label: Text('Growth scan'),
                            icon: Icon(Icons.monitor_heart_outlined)),
                        ButtonSegment(
                            value: true,
                            label: Text('Lab report'),
                            icon: Icon(Icons.bloodtype_outlined)),
                      ],
                      selected: {_isLab},
                      onSelectionChanged: (_reading || _aiJson != null)
                          ? null
                          : (s) => setState(() => _isLab = s.first),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _pages.isEmpty
                          ? 'Photograph your ${_isLab ? 'lab' : 'scan'} report'
                          : '${_pages.length} page${_pages.length == 1 ? '' : 's'} added',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add every page that has measurements — multi-page reports are read together. Cover the name/ID if you like.',
                      style: TextStyle(
                          fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _pagesGrid(context),
                    const SizedBox(height: 16),
                    if (_aiJson == null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _pages.isEmpty || _reading ? null : _read,
                        icon: _reading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.auto_awesome),
                        label: Text(_reading
                            ? 'Reading your report… about a minute'
                            : 'Read ${_pages.length == 1 ? 'the report' : '${_pages.length} pages'}'),
                      ),
                    if (_aiJson != null) ...[
                      AiResultSummary(aiJson: _aiJson!),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _save,
                        icon: const Icon(Icons.check),
                        label: const Text('Looks right — save it'),
                      ),
                      TextButton(
                        onPressed: _reading ? null : _read,
                        child: const Text('Re-read'),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _setupNudge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'One-time setup: connect your own Azure AI — then reading a scan is a single tap.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AiSettingsScreen()));
                final c = await AiConfigStore.load();
                if (mounted) setState(() => _config = c);
              },
              child: const Text('Set up AI'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagesGrid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget addButton(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (_reading || _aiJson != null) ? null : onTap,
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _pages.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_pages[i].filePath),
                    width: 92, height: 92, fit: BoxFit.cover),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: (_reading || _aiJson != null)
                      ? null
                      : () async {
                          await Attachments.delete(_pages[i].filePath);
                          if (mounted) setState(() => _pages.removeAt(i));
                        },
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: scheme.inverseSurface,
                    child: Icon(Icons.close,
                        size: 13, color: scheme.onInverseSurface),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onInverseSurface)),
                ),
              ),
            ],
          ),
        addButton(Icons.photo_camera_outlined, 'Camera',
            () => _add(Attachments.fromCamera)),
        addButton(Icons.photo_outlined, 'Gallery',
            () => _add(Attachments.fromGallery)),
      ],
    );
  }
}
