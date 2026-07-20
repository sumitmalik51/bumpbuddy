import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ai/ai_config.dart';
import '../ai/scan_job.dart';
import '../attachments.dart';
import '../models.dart';
import '../store.dart';
import 'ai_settings_screen.dart';
import 'widgets/ai_result_summary.dart';

/// The one-tap scan flow: photograph the report pages -> Read -> review ->
/// saved to Records automatically (and into the Growth chart).
///
/// The read itself runs in [ScanJobController], so leaving this screen, the
/// screen dimming, or a brief app-switch does NOT interrupt it — returning
/// here reattaches to the same job.
class ScanReadScreen extends StatefulWidget {
  const ScanReadScreen({super.key});

  @override
  State<ScanReadScreen> createState() => _ScanReadScreenState();
}

class _ScanReadScreenState extends State<ScanReadScreen> {
  late final String _recordId;
  final List<RecordAttachment> _pages = [];
  bool _isLab = false;
  AiConfig? _config;
  bool _configLoaded = false;
  bool _saved = false;

  final _jobs = ScanJobController.instance;

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

  ScanJob? get _job => _jobs.job;
  String? get _aiJson =>
      _job?.result == null ? null : jsonEncode(_job!.result);

  Future<void> _add(
      Future<List<({String fileName, String filePath})>> Function(String)
          pick) async {
    final results = await pick(_recordId);
    if (results.isEmpty || !mounted) return;
    setState(() {
      _pages.addAll(results
          .where((r) => RecordAttachment(
                  fileName: r.fileName, filePath: r.filePath)
              .isImage)
          .map((r) =>
              RecordAttachment(fileName: r.fileName, filePath: r.filePath)));
    });
  }

  void _read() {
    final store = context.read<AppStore>();
    _jobs.start(
      config: _config!,
      paths: _pages.map((p) => p.filePath).toList(),
      twinsHint: store.profile?.isTwins ?? false,
      isLab: _isLab,
    );
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final r = _job!.result!;
    var date = DateTime.now();
    if (r['report_date'] is String) {
      date = DateTime.tryParse(r['report_date'] as String) ?? date;
    }
    final isLab = r['kind'] == 'lab';
    final ga = r['gestational_age_on_report'];
    final labName = r['lab_name'];
    await store.upsertRecord(RecordItem(
      id: _recordId,
      date: date,
      category: isLab ? RecordCategory.bloodTest : RecordCategory.ultrasound,
      title: isLab
          ? 'Lab report — ${labName ?? DateFormat('d MMM').format(date)}'
          : 'Growth scan${ga != null ? ' — $ga' : ' — ${DateFormat('d MMM').format(date)}'}',
      attachments: _pages,
      aiJson: jsonEncode(r),
    ));
    _saved = true;
    _jobs.clear();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Saved — see it in Records and on the Growth chart.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = _config?.isComplete ?? false;

    return AnimatedBuilder(
      animation: _jobs,
      builder: (context, _) {
        final job = _job;
        final running = job?.running == true;
        final hasResult = job?.result != null && !_saved;
        final hasError = job?.error != null;

        return Scaffold(
          appBar: AppBar(title: const Text('Read a scan')),
          body: !_configLoaded
              ? const Center(child: CircularProgressIndicator())
              : !configured
                  ? _setupNudge(context)
                  : running
                      ? _ScanProgress(job: job!)
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
                              onSelectionChanged: hasResult
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
                                  fontSize: 12.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            _pagesGrid(context, locked: hasResult),
                            const SizedBox(height: 16),
                            if (hasError)
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(job!.error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer)),
                                ),
                              ),
                            if (!hasResult)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16)),
                                onPressed: _pages.isEmpty ? null : _read,
                                icon: const Icon(Icons.auto_awesome),
                                label: Text(hasError
                                    ? 'Try again'
                                    : 'Read ${_pages.length <= 1 ? 'the report' : '${_pages.length} pages'}'),
                              ),
                            if (hasResult) ...[
                              AiResultSummary(aiJson: _aiJson!),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16)),
                                onPressed: _save,
                                icon: const Icon(Icons.check),
                                label: const Text('Looks right — save it'),
                              ),
                              TextButton(
                                onPressed: _read,
                                child: const Text('Re-read'),
                              ),
                            ],
                          ],
                        ),
        );
      },
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

  Widget _pagesGrid(BuildContext context, {required bool locked}) {
    final scheme = Theme.of(context).colorScheme;
    Widget addButton(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: locked ? null : onTap,
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
              if (!locked)
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () async {
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
        if (!locked) ...[
          addButton(Icons.photo_camera_outlined, 'Camera',
              () => _add(Attachments.fromCamera)),
          addButton(Icons.photo_outlined, 'Gallery',
              () => _add(Attachments.fromGallery)),
        ],
      ],
    );
  }
}

/// Full-screen scanning animation + smoothed progress bar. The displayed
/// value eases toward the job's real progress and gently creeps during the
/// long request so it never looks frozen, capped just under completion.
class _ScanProgress extends StatefulWidget {
  final ScanJob job;
  const _ScanProgress({required this.job});

  @override
  State<_ScanProgress> createState() => _ScanProgressState();
}

class _ScanProgressState extends State<_ScanProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  Timer? _ease;
  double _display = 0;

  @override
  void initState() {
    super.initState();
    _ease = Timer.periodic(const Duration(milliseconds: 60), (_) {
      final target = widget.job.progress;
      // Creep toward 0.9 while the real target is stalled during a request,
      // so the bar keeps moving; snap all the way once work truly completes.
      final goal = target >= 1.0
          ? 1.0
          : (target > _display
              ? target
              : (_display + 0.0035).clamp(0.0, 0.9));
      final next = _display + (goal - _display) * 0.15;
      if ((next - _display).abs() > 0.0005) {
        setState(() => _display = next);
      }
    });
  }

  @override
  void dispose() {
    _sweep.dispose();
    _ease?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 150,
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) => CustomPaint(
                  painter: _ScanDocPainter(
                    t: _sweep.value,
                    paper: scheme.surfaceContainerHighest,
                    ink: scheme.onSurfaceVariant,
                    line: scheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(widget.job.phase,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _display,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text('${(_display * 100).round()}%',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Text(
              'Reading with AI usually takes about a minute.\nYou can lock your phone or switch apps briefly — this keeps going.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanDocPainter extends CustomPainter {
  final double t;
  final Color paper;
  final Color ink;
  final Color line;
  _ScanDocPainter(
      {required this.t,
      required this.paper,
      required this.ink,
      required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 6, size.width - 20, size.height - 12),
        const Radius.circular(10));
    canvas.drawRRect(r, Paint()..color = paper);

    // Text lines on the "report".
    final linePaint = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final left = 24.0;
    for (var i = 0; i < 6; i++) {
      final y = 30.0 + i * 18;
      final w = (i.isEven ? size.width - 56 : size.width - 84);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), linePaint);
    }

    // Sweeping scan line (down and back).
    final tt = t < 0.5 ? t * 2 : (1 - t) * 2;
    final scanY = 18 + tt * (size.height - 36);
    final glow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [line.withValues(alpha: 0), line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(10, scanY - 16, size.width - 20, 32));
    canvas.drawRect(
        Rect.fromLTWH(10, scanY - 16, size.width - 20, 32), glow);
    canvas.drawLine(Offset(14, scanY), Offset(size.width - 14, scanY),
        Paint()..color = line..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ScanDocPainter old) => old.t != t;
}
