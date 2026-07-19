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
import 'package:bumpbuddy/ai/scan_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final endpoint = Platform.environment['AZURE_OPENAI_ENDPOINT'] ?? '';
  final deployment = Platform.environment['AZURE_OPENAI_DEPLOYMENT'] ?? '';
  final apiKey = Platform.environment['AZURE_OPENAI_API_KEY'] ?? '';
  final imagePath = Platform.environment['SCAN_TEST_IMAGE'] ?? '';
  final configured = endpoint.isNotEmpty &&
      deployment.isNotEmpty &&
      apiKey.isNotEmpty &&
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

  test(
    'LIVE: extracts BOTH twins from the real growth-scan photo',
    () async {
      final result = await ScanReader.extract(
        config: AiConfig(
            endpoint: endpoint, deployment: deployment, apiKey: apiKey),
        image: File(imagePath),
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
}
