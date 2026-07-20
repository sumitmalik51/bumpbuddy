// Verifies the scan flow's new states render without exceptions by driving
// ScanJobController directly (no network): running -> progress UI, result ->
// review + save, error -> retry.

import 'package:bumpbuddy/ai/scan_job.dart';
import 'package:bumpbuddy/screens/scan_read_screen.dart';
import 'package:bumpbuddy/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({
    'ai_endpoint': 'https://x.services.ai.azure.com',
    'ai_deployment': 'gpt-5',
    'ai_api_key': 'test-key',
  });
  SharedPreferences.setMockInitialValues({
    'profile': '{"type":"twins","chorionicity":"dcda",'
        '"edd":"2026-08-17T00:00:00.000","lmp":"2025-11-10T00:00:00.000",'
        '"ivf":false,"babies":[{"label":"A","nickname":"A"},{"label":"B","nickname":"B"}],'
        '"doctorName":"","hospitalName":"","createdAt":"2026-07-20T00:00:00.000"}',
  });
  final store = AppStore();
  await store.load();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: store,
    child: const MaterialApp(home: ScanReadScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void _noException(WidgetTester tester, String where) {
  expect(tester.takeException(), isNull, reason: where);
}

void main() {
  tearDown(() => ScanJobController.instance.clear());

  testWidgets('running job renders progress UI and animates', (tester) async {
    ScanJobController.instance.job = const ScanJob(
        running: true, isLab: false, progress: 0.3, phase: 'Reading the report…');
    await _pump(tester);
    _noException(tester, 'initial running frame');
    expect(find.text('Reading the report…'), findsOneWidget);
    // Let the easing timer + sweep animation run several frames.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      _noException(tester, 'progress frame $i');
    }
  });

  testWidgets('finished job shows the save button', (tester) async {
    ScanJobController.instance.job = const ScanJob(
      running: false,
      isLab: false,
      progress: 1,
      phase: 'Done',
      result: {
        'report_date': '2026-07-19',
        'gestational_age_on_report': '35 w + 6 d',
        'twins_detected': true,
        'babies': [
          {'label': 'A', 'efw_grams': 3030},
          {'label': 'B', 'efw_grams': 2536},
        ],
        'printed_efw_discordance_percent': 16.3,
        'derived': {
          'efw_discordance_percent': 16.3,
          'efw_discordance_clinically_significant': false,
        },
      },
    );
    await _pump(tester);
    _noException(tester, 'result frame');
    expect(find.text('Looks right — save it'), findsOneWidget);
  });

  testWidgets('errored job shows the message and try-again', (tester) async {
    ScanJobController.instance.job = const ScanJob(
      running: false,
      isLab: false,
      phase: 'Couldn\'t read it',
      error: 'Azure rate limit hit (429).',
    );
    await _pump(tester);
    _noException(tester, 'error frame');
    expect(find.text('Azure rate limit hit (429).'), findsOneWidget);
  });
}
