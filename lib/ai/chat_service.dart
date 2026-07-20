import 'dart:convert';

import 'package:http/http.dart' as http;

import '../doctor_summary.dart';
import '../models.dart';
import '../store.dart';
import 'ai_config.dart';
import 'scan_reader.dart';

/// "Ask BumpBuddy" — chat grounded in the user's OWN pregnancy data.
/// Same BYO-Azure setup as the scan reader; nothing is stored server-side.
class ChatService {
  static const _apiVersion = '2024-10-21';

  static const String _systemPrompt =
      r'''You are BumpBuddy, a warm, plain-spoken pregnancy companion inside a tracking app. The user's own pregnancy data is provided below — ground every answer in it and say which of their values you used.

Non-negotiable rules:
1. EDUCATIONAL ONLY, NEVER DIAGNOSTIC. Explain what values and terms mean and what is typically discussed with a doctor. Never diagnose, never predict outcomes, never tell the user a finding is "fine" or "dangerous" — frame ranges as "commonly considered / doctors usually look at" and hand judgement to their care team.
2. NO TREATMENT OR DOSING ADVICE. Never suggest starting, stopping, or changing any medicine or dose. Supplements included.
3. RED FLAGS. If the user describes bleeding, severe headache or visual changes, reduced baby movements, fluid leaking, fever over 38°C / 100.4°F, severe abdominal pain, or regular contractions before term — tell them clearly and immediately to contact their care team or go to the hospital NOW, before any explanation.
4. TWINS AWARENESS. When their data says twins, answer per baby where relevant, and use chorionicity correctly (DCDA/MCDA/MCMA differ in monitoring and typical delivery timing).
5. HONESTY. If their data doesn't contain what's needed, say so. Never invent values. If a question needs a clinician, say "this one is for your doctor" and suggest how to phrase it.
6. STYLE. Short, kind, concrete. Use their babies' names when known. No medical lecture unless asked. End answers that touch on anything clinical with a one-line reminder that their doctor's advice comes first.''';

  /// Compact, token-light context: profile + latest readings + all scans.
  static String buildContext(AppStore store) {
    final b = StringBuffer();
    b.writeln('=== USER PREGNANCY DATA (from their device) ===');
    b.writeln(buildDoctorSummary(store));

    // All AI-read scans (not just the latest) so trends can be discussed.
    final scans = store.records
        .where((r) =>
            r.category == RecordCategory.ultrasound && r.aiJson.isNotEmpty)
        .toList()
      ..sort((a, b2) => a.date.compareTo(b2.date));
    if (scans.length > 1) {
      b.writeln('');
      b.writeln('All AI-read scans (oldest first):');
      for (final s in scans) {
        try {
          final j = jsonDecode(s.aiJson) as Map<String, dynamic>;
          final babies = ((j['babies'] ?? []) as List)
              .cast<Map<String, dynamic>>()
              .map((x) => '${x['label']}: ${x['efw_grams'] ?? '?'} g')
              .join(', ');
          final derived = (j['derived'] ?? {}) as Map<String, dynamic>;
          b.writeln(
              '  ${j['report_date'] ?? s.date.toIso8601String().substring(0, 10)}'
              ' (${j['gestational_age_on_report'] ?? 'GA n/a'}): $babies'
              '${derived['efw_discordance_percent'] != null ? ' · discordance ${derived['efw_discordance_percent']}%' : ''}');
        } catch (_) {}
      }
    }
    b.writeln('=== END USER DATA ===');
    return b.toString();
  }

  /// One-tap appointment preparation prompt.
  static String appointmentPrepQuestion(AppStore store) {
    final next = store.nextAppointment;
    return 'Prepare me for my ${next != null ? 'appointment "${next.title}"' : 'next appointment'}: '
        'summarize what changed since the previous scan/visit in my data, and give me a short list '
        'of questions worth asking my doctor. Keep it practical.';
  }

  static const _languageNames = {'en': 'English', 'hi': 'Hindi (हिन्दी)'};

  static Future<String> ask({
    required AiConfig config,
    required AppStore store,
    required List<ChatMessage> history,
    required String question,
  }) async {
    final url = Uri.parse(
        '${config.normalizedEndpoint}/openai/deployments/${config.deployment.trim()}/chat/completions?api-version=$_apiVersion');

    final langName = _languageNames[store.languageCode] ?? 'English';
    final langLine = store.languageCode == 'en'
        ? ''
        : '\n\nIMPORTANT: Reply in $langName. Keep medical terms the user will '
            'recognise (you may keep common English/clinical words) but write the '
            'explanation in $langName.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': '$_systemPrompt$langLine\n\n${buildContext(store)}'},
      // Recent turns only — the grounding context carries the real state.
      for (final m in history.length > 10
          ? history.sublist(history.length - 10)
          : history)
        {'role': m.role, 'content': m.text},
      {'role': 'user', 'content': question},
    ];

    http.Response res;
    try {
      res = await http
          .post(url,
              headers: {
                'content-type': 'application/json',
                'api-key': config.apiKey.trim(),
              },
              body: jsonEncode({
                'messages': messages,
                'max_completion_tokens': 6000,
              }))
          .timeout(const Duration(minutes: 3));
    } on Exception catch (e) {
      throw ScanReaderException('Could not reach your Azure endpoint: $e');
    }
    if (res.statusCode == 401) {
      throw ScanReaderException('Azure rejected the API key (401).');
    }
    if (res.statusCode == 429) {
      throw ScanReaderException('Rate limit (429) — try again in a minute.');
    }
    if (res.statusCode != 200) {
      throw ScanReaderException('Azure returned HTTP ${res.statusCode}.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final choice = ((body['choices'] ?? []) as List).firstOrNull;
    final content = choice?['message']?['content'];
    if (content == null || (content as String).trim().isEmpty) {
      throw ScanReaderException('The model returned an empty answer.');
    }
    return content.trim();
  }
}
