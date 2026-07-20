// LIVE end-to-end test of the in-app scan reader (tiling + Azure call +
// parsing + discordance). Runs ONLY when AZURE_OPENAI_* env vars are set
// and a real report photo path is provided via SCAN_TEST_IMAGE; otherwise
// skipped. Deliberately does NOT initialize the widget-test binding so real
// HTTP is allowed.
//
// Run:
//   flutter test test/tools/live_scan_reader_test.dart
// with AZURE_OPENAI_ENDPOINT / AZURE_OPENAI_DEPLOYMENT / AZURE_OPENAI_API_KEY
// and SCAN_TEST_IMAGE set in the environment.

import 'dart:io';

import 'package:bumpbuddy/ai/ai_config.dart';
import 'package:bumpbuddy/ai/chat_service.dart';
import 'package:bumpbuddy/ai/lab_reader.dart';
import 'package:bumpbuddy/ai/scan_reader.dart';
import 'package:bumpbuddy/models.dart';
import 'package:bumpbuddy/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final endpoint = Platform.environment['AZURE_OPENAI_ENDPOINT'] ?? '';
  final deployment = Platform.environment['AZURE_OPENAI_DEPLOYMENT'] ?? '';
  final apiKey = Platform.environment['AZURE_OPENAI_API_KEY'] ?? '';
  final imagePath = Platform.environment['SCAN_TEST_IMAGE'] ?? '';
  final azureConfigured =
      endpoint.isNotEmpty && deployment.isNotEmpty && apiKey.isNotEmpty;
  final configured = azureConfigured &&
      imagePath.isNotEmpty &&
      File(imagePath).existsSync();

  test('tiling: large photo becomes overview + tiles, small passes through',
      () {
    final big = img.Image(width: 3200, height: 5700);
    final bigParts = buildImagePartsB64(
        img.encodeJpg(big, quality: 60));
    // 3200x5700 -> 2 cols x 3 rows = 6 tiles + 1 overview
    expect(bigParts.length, 7);

    final small = img.Image(width: 1000, height: 1400);
    final smallParts =
        buildImagePartsB64(img.encodeJpg(small, quality: 60));
    expect(smallParts.length, 1);
  });

  test('mergePages: field-wise first-non-null, babies unified by label', () {
    final page1 = {
      'report_date': '2026-07-19',
      'gestational_age_on_report': '35 w + 6 d',
      'twins_detected': true,
      'babies': [
        {'label': 'A', 'efw_grams': 3030, 'fhr_bpm': 126, 'dvp_cm': 6.1},
        {'label': 'B', 'efw_grams': 2536, 'fhr_bpm': null, 'dvp_cm': null},
      ],
      'printed_efw_discordance_percent': 16.3,
      'impression': null,
      'flags': ['DCDA documented'],
      'confidence_notes': 'Fetus B clinical not on this page',
    };
    // Page 2 MIS-LABELS Fetus B's block as "A" (observed on real reports
    // when a photo starts mid-way through Fetus A's section) — the merge
    // must recognise the weight fingerprint and reassign it to B.
    final page2 = {
      'report_date': null,
      'gestational_age_on_report': null,
      'twins_detected': true,
      'babies': [
        {'label': 'A', 'efw_grams': 2536, 'fhr_bpm': 138, 'dvp_cm': 2.2},
      ],
      'printed_efw_discordance_percent': 16.3,
      'impression': 'DCDA live IUP',
      'flags': ['DCDA documented', 'page starts mid-report'],
      'confidence_notes': null,
    };
    final merged = ScanReader.mergePages([page1, page2]);
    final babies = (merged['babies'] as List).cast<Map<String, dynamic>>();
    expect(babies.length, 2);
    final a = babies.firstWhere((b) => b['label'] == 'A');
    final b = babies.firstWhere((b) => b['label'] == 'B');
    expect(a['fhr_bpm'], 126);
    expect(b['efw_grams'], 2536);
    expect(b['fhr_bpm'], 138); // filled from page 2
    expect(b['dvp_cm'], 2.2); // filled from page 2
    expect(merged['report_date'], '2026-07-19');
    expect(merged['impression'], 'DCDA live IUP');
    expect(
        (merged['flags'] as List)
            .any((f) => (f as String).contains('Reassigned')),
        isTrue,
        reason: 'relabeling must be disclosed in flags');
    final derived = ScanReader.computeDiscordance(merged);
    expect(derived['efw_discordance_percent'], 16.3);
  });

  test(
    'LIVE: extracts BOTH twins from the real growth-scan photo',
    () async {
      final result = await ScanReader.extract(
        config: AiConfig(
            endpoint: endpoint, deployment: deployment, apiKey: apiKey),
        images: [File(imagePath)],
        twinsHint: true,
      );

      final babies =
          (result['babies'] as List).cast<Map<String, dynamic>>();
      expect(result['twins_detected'], true);
      expect(babies.length, 2);

      final a = babies.firstWhere((b) => b['label'] == 'A');
      final b = babies.firstWhere((b) => b['label'] == 'B');

      // Ground truth printed on IMG_1020 (latest exam 19/07/2026).
      expect(a['efw_grams'], 3030);
      expect(a['hc_mm'], 338.3);
      expect(b['efw_grams'], 2536, reason: 'Baby B EFW must not be null — this was the pre-tiling failure');
      expect(b['bpd_mm'], 87.4);
      expect(b['hc_mm'], 299.2);
      expect(b['ac_mm'], 320.5);
      expect(b['fl_mm'], 64.3);

      // Printed discordance captured, and our own math now computable.
      expect(result['printed_efw_discordance_percent'], 16.3);
      final derived = result['derived'] as Map<String, dynamic>;
      expect(derived['efw_discordance_percent'], 16.3);
      expect(derived['efw_discordance_clinically_significant'], false);
    },
    skip: configured
        ? false
        : 'Set AZURE_OPENAI_* and SCAN_TEST_IMAGE env vars to run live',
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    'LIVE: chat answers a growth question from the seeded data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore();
      await store.load();
      await store.saveProfile(PregnancyProfile(
        type: PregnancyType.twins,
        chorionicity: Chorionicity.dcda,
        edd: DateTime(2026, 8, 17),
        lmp: DateTime(2025, 11, 10),
        babies: [
          Baby(label: 'A', nickname: 'guchi'),
          Baby(label: 'B', nickname: 'armani')
        ],
      ));
      await store.upsertRecord(RecordItem(
        id: 'r1',
        date: DateTime(2026, 7, 19),
        category: RecordCategory.ultrasound,
        title: 'Growth scan',
        aiJson:
            '{"report_date":"2026-07-19","gestational_age_on_report":"35 w + 6 d","twins_detected":true,'
            '"babies":[{"label":"A","efw_grams":3030},{"label":"B","efw_grams":2536}],'
            '"printed_efw_discordance_percent":16.3,"impression":null,"flags":[],"confidence_notes":null,'
            '"derived":{"efw_discordance_percent":16.3,"efw_discordance_clinically_significant":false}}',
      ));

      final answer = await ChatService.ask(
        config: AiConfig(
            endpoint: endpoint, deployment: deployment, apiKey: apiKey),
        store: store,
        history: const [],
        question: 'How are my twins growing? Use my latest scan.',
      );
      expect(answer.length, greaterThan(80));
      // Grounding check: the answer must reference their actual data.
      expect(
        answer.contains('3030') ||
            answer.contains('2536') ||
            answer.toLowerCase().contains('guchi') ||
            answer.toLowerCase().contains('armani'),
        isTrue,
        reason: 'answer should cite the user\'s own values: $answer',
      );
    },
    skip: azureConfigured ? false : 'Set AZURE_OPENAI_* env vars to run live',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  final labImage = Platform.environment['LAB_TEST_IMAGE'] ?? '';
  test(
    'LIVE: lab reader transcribes a CBC with printed flags and ranges',
    () async {
      final result = await LabReader.extract(
        config: AiConfig(
            endpoint: endpoint, deployment: deployment, apiKey: apiKey),
        images: [File(labImage)],
      );
      expect(result['kind'], 'lab');
      final tests =
          (result['tests'] as List).cast<Map<String, dynamic>>();
      Map<String, dynamic> byName(String needle) => tests.firstWhere(
          (t) => (t['name'] as String).toLowerCase().contains(needle));
      final hb = byName('emoglobin');
      expect(hb['value'], 10.4);
      expect((hb['flag'] ?? '').toString().toUpperCase(), contains('L'));
      expect(hb['reference_range'], contains('11'));
      final tsh = byName('tsh');
      expect(tsh['value'], 2.4);
      expect(tsh['flag'], isNull, reason: 'TSH has no printed flag');
      final fpg = byName('glucose');
      expect(fpg['value'], 84);
    },
    skip: (azureConfigured &&
            labImage.isNotEmpty &&
            File(labImage).existsSync())
        ? false
        : 'Set AZURE_OPENAI_* and LAB_TEST_IMAGE to run live',
    timeout: const Timeout(Duration(minutes: 6)),
  );

  final imagePath2 = Platform.environment['SCAN_TEST_IMAGE2'] ?? '';
  test(
    'LIVE: merges a TWO-PAGE report into one complete extraction',
    () async {
      final result = await ScanReader.extract(
        config: AiConfig(
            endpoint: endpoint, deployment: deployment, apiKey: apiKey),
        images: [File(imagePath), File(imagePath2)],
        twinsHint: true,
      );
      final babies =
          (result['babies'] as List).cast<Map<String, dynamic>>();
      expect(babies.length, 2);
      final a = babies.firstWhere((b) => b['label'] == 'A');
      final b = babies.firstWhere((b) => b['label'] == 'B');

      // Page 1 carries the growth tables; page 2 carries Fetus B's full
      // clinical block (FHR 138, placenta grade 2, MVP 2.2 cm).
      expect(a['efw_grams'], 3030);
      expect(b['efw_grams'], 2536);
      expect(b['fhr_bpm'], 138, reason: 'Fetus B FHR is only on page 2');
      expect(b['dvp_cm'], 2.2, reason: 'Fetus B MVP is only on page 2');
      expect((b['placenta_grade'] ?? '').toString().toLowerCase(),
          contains('2'));
    },
    skip: (configured && imagePath2.isNotEmpty && File(imagePath2).existsSync())
        ? false
        : 'Set AZURE_OPENAI_*, SCAN_TEST_IMAGE and SCAN_TEST_IMAGE2 to run live',
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
