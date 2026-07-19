import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'ai_config.dart';

/// Dart port of tools/scan-poc extract.js (Azure provider).
/// Same system prompt, same strict JSON schema, same guardrails —
/// validated against real reports before this port. Keep the two in sync.
class ScanReader {
  static const _apiVersion = '2024-10-21';
  static const _maxTokens = 16000;

  static const _mediaTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
  };

  static const Map<String, dynamic> _babySchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'label', 'presentation', 'efw_grams', 'efw_raw', 'hc_mm', 'hc_raw',
      'ac_mm', 'ac_raw', 'fl_mm', 'fl_raw', 'bpd_mm', 'bpd_raw', 'fhr_bpm',
      'placenta', 'placenta_grade', 'liquor_afi_cm', 'dvp_cm',
      'umbilical_doppler',
    ],
    'properties': {
      'label': {
        'type': 'string',
        'description':
            'Normalized single-letter label in document order: "A", "B", ... (Twin A / Fetus 1 / F1 -> "A").',
      },
      'presentation': {
        'type': ['string', 'null'],
        'description':
            'Fetal presentation as printed (e.g. cephalic, breech, transverse).',
      },
      'efw_grams': {
        'type': ['number', 'null'],
        'description':
            'Estimated fetal weight in grams. If printed as a range or with a tolerance, the central value. Null if absent or not safely convertible.',
      },
      'efw_raw': {
        'type': ['string', 'null'],
        'description':
            'Verbatim EFW text from the report when it is a range, has a tolerance, uses non-gram units, or is otherwise ambiguous. Null when efw_grams is an unambiguous plain number.',
      },
      'hc_mm': {
        'type': ['number', 'null'],
        'description':
            'Head circumference in millimetres (convert cm -> mm). Null if only a week-equivalent is printed.',
      },
      'hc_raw': {
        'type': ['string', 'null'],
        'description':
            'Verbatim HC text when ambiguous or week-based (e.g. "HC = 32w4d").',
      },
      'ac_mm': {
        'type': ['number', 'null'],
        'description':
            'Abdominal circumference in millimetres (convert cm -> mm).',
      },
      'ac_raw': {
        'type': ['string', 'null'],
        'description': 'Verbatim AC text when ambiguous or week-based.',
      },
      'fl_mm': {
        'type': ['number', 'null'],
        'description': 'Femur length in millimetres (convert cm -> mm).',
      },
      'fl_raw': {
        'type': ['string', 'null'],
        'description': 'Verbatim FL text when ambiguous or week-based.',
      },
      'bpd_mm': {
        'type': ['number', 'null'],
        'description':
            'Biparietal diameter in millimetres (convert cm -> mm).',
      },
      'bpd_raw': {
        'type': ['string', 'null'],
        'description': 'Verbatim BPD text when ambiguous or week-based.',
      },
      'fhr_bpm': {
        'type': ['number', 'null'],
        'description': 'Fetal heart rate in beats per minute.',
      },
      'placenta': {
        'type': ['string', 'null'],
        'description':
            'Placental location/description as printed (e.g. anterior, posterior, fundal, low-lying).',
      },
      'placenta_grade': {
        'type': ['string', 'null'],
        'description':
            'Placental maturity grade as printed (e.g. "Grade II", "Gr. 2").',
      },
      'liquor_afi_cm': {
        'type': ['number', 'null'],
        'description': 'Amniotic fluid index (AFI / liquor) in centimetres.',
      },
      'dvp_cm': {
        'type': ['number', 'null'],
        'description':
            'Deepest vertical pocket (DVP / SDP / MVP) in centimetres.',
      },
      'umbilical_doppler': {
        'type': ['string', 'null'],
        'description':
            'Umbilical artery Doppler findings as printed (e.g. S/D ratio, PI, RI values, end-diastolic flow status). Verbatim, no interpretation.',
      },
    },
  };

  static const Map<String, dynamic> outputSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'report_date', 'gestational_age_on_report', 'twins_detected', 'babies',
      'printed_efw_discordance_percent', 'impression', 'flags',
      'confidence_notes',
    ],
    'properties': {
      'report_date': {
        'type': ['string', 'null'],
        'description':
            'Date of the scan/report. ISO 8601 (YYYY-MM-DD) if unambiguous on the report; otherwise verbatim as printed. Null if not printed.',
      },
      'gestational_age_on_report': {
        'type': ['string', 'null'],
        'description':
            'Gestational age stated on the report, verbatim (e.g. "32 weeks 4 days", "32w4d"). Null if not printed.',
      },
      'twins_detected': {
        'type': 'boolean',
        'description':
            'True only if the report clearly documents more than one fetus.',
      },
      'babies': {
        'type': 'array',
        'description':
            'One entry per fetus documented on the report, in document order.',
        'items': _babySchema,
      },
      'printed_efw_discordance_percent': {
        'type': ['number', 'null'],
        'description':
            "EFW discordance percentage AS PRINTED on the report (e.g. in a fetal weight calculation box: 'EFW discordance 16.3 %'). Transcription only — never compute this yourself. Null if the report does not print one.",
      },
      'impression': {
        'type': ['string', 'null'],
        'description':
            "The report's own impression/conclusion section, transcribed (may be lightly abbreviated). NEVER the model's own assessment. Null if the report has no such section.",
      },
      'flags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Short factual notes about documented findings or data-quality issues (no advice, no diagnosis).',
      },
      'confidence_notes': {
        'type': ['string', 'null'],
        'description':
            'Which fields were set to null (or are low-confidence) and why: illegible, cut off, blurry, ambiguous units, etc. Null if everything was clearly legible.',
      },
    },
  };

  static const String systemPrompt =
      r'''You are a medical-report DATA EXTRACTION engine embedded in a pregnancy-tracking app. You will be shown a photograph or scan of an obstetric ultrasound growth-scan report.

Non-negotiable rules:

1. EXTRACTION ONLY. Transcribe and normalize values that are literally printed on the report. Do not diagnose, interpret, predict outcomes, or offer medical opinions of any kind.
2. NO REASSURANCE, NO ALARM. Never add commentary such as "this looks normal" or "this is concerning". The "impression" field must be a transcription of the report's own impression/conclusion section — never your assessment. If the report has no impression section, set it to null.
3. NEVER GUESS. If a value is absent, illegible, cut off, blurred, overexposed, or ambiguous, set that field to null and explain which fields were affected and why in "confidence_notes". A null with an explanation is always better than a plausible guess.
4. NORMALIZE UNITS. EFW in grams; HC/AC/FL/BPD in millimetres; AFI (liquor) and DVP in centimetres; FHR in beats per minute. If the report prints a length in cm for a mm field, convert (1 cm = 10 mm) and keep the verbatim text in the matching *_raw field. If a biometry value is printed ONLY as a gestational-age equivalent (e.g. "HC = 32w4d") or in a unit you cannot safely convert, put the verbatim text in the *_raw field and set the numeric field to null — do not convert weeks to millimetres.
5. INDIAN RADIOLOGY CONVENTIONS are common: EFW usually in grams, sometimes with a tolerance or range ("1897 +/- 277 gm") — use the central value for efw_grams and keep the full text in efw_raw. Biometry tables often show a measurement column AND a week-equivalent column — extract the measurement, and use *_raw only if the measurement column is missing or unreadable. "Liquor" means amniotic fluid. Placental grading appears as Grade 0-III (or 1-3).
6. TWIN LABELS. Babies may be labelled "Twin A/Twin B", "Fetus 1/Fetus 2", "F1/F2", "Baby A/Baby B", or similar. Normalize to "A", "B", "C"... in document order (Twin A / Fetus 1 / F1 -> "A"). Set twins_detected to true only if the report clearly documents more than one fetus. Never invent a second fetus.
7. FLAGS are short, factual, and derived only from what the report documents or from data-quality issues (e.g. "AFI recorded for only one fetus", "biometry table partially cut off"). No advice, no severity judgements.
8. MULTI-FETUS COMPLETENESS. Twin reports repeat an identical table or block per fetus — commonly stacked vertically (Fetus 1's table directly above Fetus 2's) or in consecutive sections; a photo may also begin mid-way through one fetus's section. Extract EVERY fetus's values with equal care. Before finalizing, self-check: if twins_detected is true but one fetus has all-null biometry while another is fully populated, RE-EXAMINE the image for the sparse fetus's table or block — it is usually present and just as legible as the first. Attribute each clinical value (FHR, presentation, placenta, amniotic fluid) to the fetus in whose labelled section it is printed — never attach the first values you encounter to Fetus A by default. If attribution is genuinely unclear, leave the field null and record the ambiguity in flags.
9. STRUCTURE/FLAGS CONSISTENCY. Never mention a numeric value in flags or confidence_notes (for example a printed discordance percentage or an EFW) while leaving the corresponding structured field null. If it is legible enough to mention, it is legible enough to extract.

Your entire output must conform to the provided JSON schema.''';

  static String userPrompt(bool twinsHint) {
    var prompt =
        r'''Extract the structured data from this ultrasound growth-scan report photo.

Steps:
1. Read the report header for the scan/report date and the stated gestational age.
2. Identify how many fetuses the report documents and their labels.
3. For each fetus, extract: presentation, EFW, HC, AC, FL, BPD, FHR, placenta location and grade, liquor/AFI, DVP, and umbilical artery Doppler findings — normalizing units per the system rules and using the *_raw fields for verbatim text whenever a value is ambiguous, ranged, or week-based.
4. If the report prints an EFW discordance percentage, transcribe it into printed_efw_discordance_percent.
5. Transcribe the report's impression/conclusion section if present.
6. Record any documented notable findings or data-quality problems in "flags", and explain every null / low-confidence field in "confidence_notes".''';
    if (twinsHint) {
      prompt +=
          r'''

Note: the user has indicated this is a TWIN pregnancy. Look carefully for a second fetus — twin reports often present per-fetus data in side-by-side columns, sequential blocks, or a shared table with Twin A / Twin B (or Fetus 1 / Fetus 2, F1 / F2) columns. If the report nevertheless documents only one fetus, do NOT invent a second baby: return the single baby, set twins_detected accordingly, and record the mismatch in flags and confidence_notes.''';
    }
    return prompt;
  }

  /// Runs extraction on a report photo. Throws [ScanReaderException] with a
  /// user-friendly message on failure.
  static Future<Map<String, dynamic>> extract({
    required AiConfig config,
    required File image,
    required bool twinsHint,
  }) async {
    final ext = image.path
        .substring(image.path.lastIndexOf('.'))
        .toLowerCase();
    final mediaType = _mediaTypes[ext];
    if (mediaType == null) {
      throw ScanReaderException(
          'Only JPG, PNG and WebP photos can be read (got $ext).');
    }
    final bytes = await image.readAsBytes();

    // Azure's vision pipeline downscales large photos so hard that small
    // table digits become unreadable to the model (validated on real
    // reports: a full 3213x5712 photo lost a whole fetus's biometry table;
    // crops of the same photo read perfectly). For big images we therefore
    // send an overview plus overlapping high-resolution tiles of the SAME
    // page in one request.
    final tiles = await compute(buildImagePartsB64, bytes);
    final imageParts = tiles
        .map((b64) => {
              'type': 'image_url',
              'image_url': {
                'url': 'data:${tiles.length > 1 ? 'image/jpeg' : mediaType};base64,$b64',
                'detail': 'high',
              },
            })
        .toList();

    final tilingNote = tiles.length > 1
        ? 'The report page is provided as ${tiles.length} images: first a full-page '
            'overview for layout, then ${tiles.length - 1} overlapping high-resolution '
            'crops of the SAME single page in reading order (left to right, top to '
            'bottom). Regions repeat across crops — deduplicate; every value still '
            'belongs to one single report page.\n\n'
        : '';

    final url = Uri.parse(
        '${config.normalizedEndpoint}/openai/deployments/${config.deployment.trim()}/chat/completions?api-version=$_apiVersion');

    final payload = {
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            ...imageParts,
            {'type': 'text', 'text': tilingNote + userPrompt(twinsHint)},
          ],
        },
      ],
      'max_completion_tokens': _maxTokens,
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'scan_extraction',
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

    if (res.statusCode == 401) {
      throw ScanReaderException(
          'Azure rejected the API key (401). Check AI settings — keys are per-resource.');
    }
    if (res.statusCode == 404) {
      throw ScanReaderException(
          'Deployment "${config.deployment}" not found (404). The deployment NAME from Foundry may differ from the model name.');
    }
    if (res.statusCode == 429) {
      throw ScanReaderException(
          'Azure rate limit hit (429). Wait a minute and try again.');
    }
    if (res.statusCode != 200) {
      throw ScanReaderException(
          'Azure returned HTTP ${res.statusCode}: ${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choice = ((body['choices'] ?? []) as List).firstOrNull;
    if (choice == null) {
      throw ScanReaderException('Azure returned no result.');
    }
    final finish = choice['finish_reason'];
    if (finish == 'content_filter') {
      throw ScanReaderException(
          'Azure content filter blocked this image. Try a clearer photo without unrelated content.');
    }
    final content = choice['message']?['content'];
    if (content == null || (content as String).isEmpty) {
      throw ScanReaderException('The model returned an empty extraction.');
    }
    final result = jsonDecode(content) as Map<String, dynamic>;

    // Derived, computed here — never by the model.
    result['derived'] = computeDiscordance(result);
    return result;
  }

  /// Inter-twin EFW discordance: (larger - smaller) / larger * 100.
  /// >= 20% is commonly treated as clinically significant.
  static Map<String, dynamic> computeDiscordance(Map<String, dynamic> result) {
    final babies = ((result['babies'] ?? []) as List)
        .cast<Map<String, dynamic>>()
        .where((b) => b['efw_grams'] is num && (b['efw_grams'] as num) > 0)
        .toList();
    if (babies.length < 2) {
      return {
        'efw_discordance_percent': null,
        'efw_discordance_clinically_significant': null,
        'note': 'Needs EFW for two babies.',
      };
    }
    final weights = babies.map((b) => (b['efw_grams'] as num).toDouble());
    final max = weights.reduce((a, b) => a > b ? a : b);
    final min = weights.reduce((a, b) => a < b ? a : b);
    final pct = (max - min) / max * 100;
    final rounded = (pct * 10).round() / 10;
    return {
      'efw_discordance_percent': rounded,
      'efw_discordance_clinically_significant': pct >= 20,
      'note': pct >= 20
          ? 'clinically significant discordance — discuss with doctor'
          : 'below the 20% threshold commonly used for clinically significant discordance',
    };
  }
}

class ScanReaderException implements Exception {
  final String message;
  ScanReaderException(this.message);
  @override
  String toString() => message;
}

/// Splits a large report photo into base64 JPEG parts:
/// [overview, tile1, tile2, ...] in reading order (left-to-right,
/// top-to-bottom, ~12% overlap). Small images pass through unchanged.
/// Top-level function so it can run on a background isolate via compute().
List<String> buildImagePartsB64(Uint8List bytes) {
  const maxPlainSide = 2300; // below this, Azure's resize keeps text legible
  const tileTarget = 2000.0; // aim tiles near this size per side
  const overlapFrac = 0.12;

  final decoded = img.decodeImage(bytes);
  if (decoded == null ||
      (decoded.width <= maxPlainSide && decoded.height <= maxPlainSide)) {
    return [base64Encode(bytes)];
  }

  final w = decoded.width;
  final h = decoded.height;
  final parts = <String>[];

  // Full-page overview for global layout / fetus-block attribution.
  final overview = w >= h
      ? img.copyResize(decoded, width: 1400)
      : img.copyResize(decoded, height: 1400);
  parts.add(base64Encode(img.encodeJpg(overview, quality: 82)));

  final cols = (w / tileTarget).ceil().clamp(1, 3);
  final rows = (h / tileTarget).ceil().clamp(1, 4);
  final tileW = (w / cols).ceil();
  final tileH = (h / rows).ceil();
  final overlapX = (tileW * overlapFrac).round();
  final overlapY = (tileH * overlapFrac).round();

  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final x = (col * tileW - (col > 0 ? overlapX : 0)).clamp(0, w - 1);
      final y = (row * tileH - (row > 0 ? overlapY : 0)).clamp(0, h - 1);
      final cw = (tileW + (col > 0 ? overlapX : 0)).clamp(1, w - x);
      final ch = (tileH + (row > 0 ? overlapY : 0)).clamp(1, h - y);
      final tile =
          img.copyCrop(decoded, x: x, y: y, width: cw, height: ch);
      parts.add(base64Encode(img.encodeJpg(tile, quality: 85)));
    }
  }
  return parts;
}
