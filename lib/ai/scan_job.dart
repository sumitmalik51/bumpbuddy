import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'ai_config.dart';
import 'lab_reader.dart';
import 'scan_reader.dart';

/// A single running (or finished) scan/lab read.
@immutable
class ScanJob {
  final bool running;
  final bool isLab;
  final double progress; // 0..1
  final String phase;
  final Map<String, dynamic>? result; // set when finished successfully
  final String? error; // set when finished with an error

  const ScanJob({
    required this.running,
    required this.isLab,
    this.progress = 0,
    this.phase = '',
    this.result,
    this.error,
  });

  bool get done => result != null || error != null;

  ScanJob copyWith({
    bool? running,
    double? progress,
    String? phase,
    Map<String, dynamic>? result,
    String? error,
  }) =>
      ScanJob(
        running: running ?? this.running,
        isLab: isLab,
        progress: progress ?? this.progress,
        phase: phase ?? this.phase,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

/// Owns the AI read so it survives the scan screen being left, the device
/// screen dimming, or a brief backgrounding — the operation is NOT tied to
/// any widget's lifecycle. A wakelock is held for the duration so the OS
/// doesn't suspend the request mid-flight.
///
/// (A full OS kill of a long-backgrounded app would still need a foreground
/// service; this covers screen-off, navigation, and short app switches,
/// which are the common interruption causes.)
class ScanJobController extends ChangeNotifier {
  static final ScanJobController instance = ScanJobController._();
  ScanJobController._();

  ScanJob? job;
  int _token = 0;

  bool get isRunning => job?.running == true;

  Future<void> start({
    required AiConfig config,
    required List<String> paths,
    required bool twinsHint,
    required bool isLab,
  }) async {
    if (isRunning) return;
    final token = ++_token;
    job = ScanJob(
        running: true, isLab: isLab, progress: 0.03, phase: 'Preparing pages…');
    notifyListeners();

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    void report(double p, String phase) {
      if (token != _token) return;
      job = job!.copyWith(progress: p, phase: phase);
      notifyListeners();
    }

    try {
      final files = paths.map((p) => File(p)).toList();
      final result = isLab
          ? await LabReader.extract(
              config: config, images: files, onProgress: report)
          : await ScanReader.extract(
              config: config,
              images: files,
              twinsHint: twinsHint,
              onProgress: report);
      if (token == _token) {
        job = job!.copyWith(
            running: false, progress: 1, phase: 'Done', result: result);
        notifyListeners();
      }
    } catch (e) {
      if (token == _token) {
        job = job!.copyWith(
            running: false,
            phase: 'Couldn\'t read it',
            error: e is ScanReaderException ? e.message : e.toString());
        notifyListeners();
      }
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  /// Clears a finished job (call after the result is saved or dismissed).
  void clear() {
    if (isRunning) return;
    _token++;
    job = null;
    notifyListeners();
  }
}
