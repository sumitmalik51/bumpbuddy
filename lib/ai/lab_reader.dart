import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_config.dart';
import 'scan_reader.dart';

/// Lab-report (blood/urine) extraction — same BYO-Azure, same guardrails,
/// same tiling as the scan reader, but with a generic test-panel schema so
/// ANY lab panel (CBC, OGTT, thyroid, urine) can be transcribed and trended.
class LabReader {
  static const _apiVersion = '2024-10-21';

  static const Map<String, dynamic> outputSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'report_date',
      'lab_name',
      'tests',
      'notes',
      'confidence_notes',
    ],
    'properties': {
      'report_date': {
        'type': ['string', 'null'],
        'description':
            'Report/collection date, ISO 8601 (YYYY-MM-DD) if unambiguous, else verbatim. Null if not printed.',
      },
      'lab_name': {
        'type': ['string', 'null'],
        'description': 'Laboratory/diagnostic centre name as printed.',
      },
      'tests': {
        'type': 'array',
        'description': 'One entry per analyte/result row printed on the report.',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': [
            'name',
            'value',
            'value_raw',
            'unit',
            'reference_range',
            'flag',
          ],
          'properties': {
            'name': {
              'type': 'string',
              'description':
                  'Test name, lightly normalized (e.g. "Haemoglobin"/"HGB" -> "Hemoglobin"; "T.S.H." -> "TSH"; keep panel qualifiers like "Fasting").',
            },
            'value': {
              'type': ['number', 'null'],
              'description':
                  'Numeric result. Null when the result is text (e.g. "Negative", "Trace") — put it in value_raw.',
            },
            'value_raw': {
              'type': ['string', 'null'],
              'description':
                  'Verbatim result text when non-numeric or ambiguous. Null when value is a plain number.',
            },
            'unit': {
              'type': ['string', 'null'],
              'description': 'Unit exactly as printed (g/dL, mIU/L, %, …).',
            },
            'reference_range': {
              'type': ['string', 'null'],
              'description':
                  'The reference range EXACTLY as printed on this report (labs differ; never substitute your own).',
            },
            'flag': {
              'type': ['string', 'null'],
              'description':
                  'Only a flag PRINTED on the report (H, L, High, Low, *). Null when the report prints none — never derive one yourself.',
            },
          },
        },
      },
      'notes': {
        'type': ['string', 'null'],
        'description':
            'The report\'s own remarks/impression section, transcribed. Never your assessment.',
      },
      'confidence_notes': {
        'type': ['string', 'null'],
        'description':
            'Which fields were null/low-confidence and why (illegible, cut off, ambiguous).',
      },
    },
  };

  static const String systemPrompt =
      r'''You are a lab-report DATA EXTRACTION engine inside a pregnancy-tracking app. You will be shown a photograph of a laboratory report (CBC, glucose/OGTT, thyroid, urine, LFT/KFT, etc.).

Non-negotiable rules:
1. TRANSCRIPTION ONLY. Copy what is printed: test names, values, units, reference ranges, and any printed H/L flags. Do not interpret, do not diagnose, do not comment on whether values are concerning.
2. NEVER GUESS. Illegible or cut-off values -> null with an explanation in confidence_notes. A null is always better than a plausible guess.
3. RANGES AS PRINTED. Reference ranges differ between labs and in pregnancy — transcribe the range printed on THIS report only; never substitute textbook ranges. If the report prints no range for a test, reference_range is null.
4. FLAGS AS PRINTED. Only report H/L/High/Low/* flags that the report itself prints. Never derive a flag by comparing value to range yourself. Printed flags commonly appear as a letter or symbol IMMEDIATELY AFTER the result value (e.g. "10.4 L", "31.5 L", "13.2 H", "250*") or in a dedicated flag column — capture those; do not mistake them for part of the value or unit.
5. NAMES lightly normalized for trending: expand obvious abbreviations consistently (HGB->Hemoglobin, PLT->Platelet Count, TSH stays TSH), keep qualifiers ("Fasting Plasma Glucose", "2hr Post Glucose").
6. Indian lab conventions are common (g/dL, lakhs/cumm, mIU/L). Keep units verbatim.

Your entire output must conform to the provided JSON schema.''';

  static Future<Map<String, dynamic>> extract({
    required AiConfig config,
    required List<File> images,
    void Function(double progress, String phase)? onProgress,
  }) async {
    if (images.isEmpty) {
      throw ScanReaderException('Attach at least one report photo first.');
    }
    if (images.length > 4) {
      throw ScanReaderException('Up to 4 pages per reading, please.');
    }

    onProgress?.call(0.1, 'Reading the report…');
    var done = 0;
    final pages = await Future.wait([
      for (var i = 0; i < images.length; i++)
        _extractPage(config, images[i], pageIndex: i, pageCount: images.length)
            .then((r) {
          done++;
          onProgress?.call(
              0.1 + 0.8 * done / images.length, 'Read $done of ${images.length}…');
          return r;
        }),
    ]);
    onProgress?.call(0.95, 'Organizing results…');
    final merged = mergePages(pages);
    merged['kind'] = 'lab';
    onProgress?.call(1.0, 'Done');
    return merged;
  }

  /// Concatenate tests across pages; dedupe identical rows (overlap between
  /// page photos). First non-null wins for scalars.
  static Map<String, dynamic> mergePages(List<Map<String, dynamic>> pages) {
    dynamic firstNonNull(Iterable<dynamic> values) =>
        values.firstWhere((v) => v != null, orElse: () => null);
    final tests = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final page in pages) {
      for (final t in ((page['tests'] ?? []) as List)) {
        final test = (t as Map).cast<String, dynamic>();
        final key =
            '${(test['name'] ?? '').toString().toLowerCase()}|${test['value']}|${test['value_raw']}';
        if (seen.add(key)) tests.add(test);
      }
    }
    final notes = <String>[];
    for (var i = 0; i < pages.length; i++) {
      final n = pages[i]['confidence_notes'];
      if (n is String && n.isNotEmpty) notes.add('Page ${i + 1}: $n');
    }
    return {
      'report_date': firstNonNull(pages.map((p) => p['report_date'])),
      'lab_name': firstNonNull(pages.map((p) => p['lab_name'])),
      'tests': tests,
      'notes': firstNonNull(pages.map((p) => p['notes'])),
      'confidence_notes': notes.isEmpty ? null : notes.join(' | '),
    };
  }

  static Future<Map<String, dynamic>> _extractPage(
    AiConfig config,
    File image, {
    required int pageIndex,
    required int pageCount,
  }) async {
    final bytes = await image.readAsBytes();
    final tiles = await compute(buildImagePartsB64, bytes);
    final imageParts = [
      for (final b64 in tiles)
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$b64',
            'detail': 'high',
          },
        },
    ];

    var note = '';
    if (tiles.length > 1) {
      note =
          'The page is provided as ${tiles.length} images: a full-page overview, then '
          'overlapping high-resolution crops of the SAME page in reading order. '
          'Deduplicate repeats.\n\n';
    }
    if (pageCount > 1) {
      note =
          'This is page ${pageIndex + 1} of $pageCount; other pages are processed '
          'separately — extract only what THIS page shows.\n\n$note';
    }

    final url = Uri.parse(
        '${config.normalizedEndpoint}/openai/deployments/${config.deployment.trim()}/chat/completions?api-version=$_apiVersion');
    final payload = {
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            ...imageParts,
            {
              'type': 'text',
              'text':
                  '${note}Transcribe every test row on this lab report into the schema.',
            },
          ],
        },
      ],
      'max_completion_tokens': 16000,
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'lab_extraction',
          'strict': true,
          'schema': outputSchema,
        },
      },
    };

    http.Response res;
    try {
      res = await http
          .post(url,
              headers: {
                'content-type': 'application/json',
                'api-key': config.apiKey.trim(),
              },
              body: jsonEncode(payload))
          .timeout(const Duration(minutes: 4));
    } on Exception catch (e) {
      throw ScanReaderException('Could not reach your Azure endpoint: $e');
    }
    if (res.statusCode != 200) {
      throw ScanReaderException('Azure returned HTTP ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final content =
        ((body['choices'] ?? []) as List).firstOrNull?['message']?['content'];
    if (content == null || (content as String).isEmpty) {
      throw ScanReaderException('The model returned an empty extraction.');
    }
    return jsonDecode(content) as Map<String, dynamic>;
  }
}
