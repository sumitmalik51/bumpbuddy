import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../store.dart';

/// Answers the user bookmarked from Ask BumpBuddy.
class SavedAnswersScreen extends StatelessWidget {
  const SavedAnswersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final saved = store.savedAnswers;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved answers')),
      body: saved.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border,
                        size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Tap the bookmark on any answer in Ask BumpBuddy to keep it here for quick reference.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              itemBuilder: (context, i) {
                final s = saved[i];
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.question.isNotEmpty)
                          Text(s.question,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary)),
                        const SizedBox(height: 6),
                        Text(s.answer),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(DateFormat('d MMM').format(s.time),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant)),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.ios_share, size: 18),
                              onPressed: () => SharePlus.instance.share(
                                  ShareParams(
                                      text:
                                          '${s.question.isNotEmpty ? '${s.question}\n\n' : ''}${s.answer}\n\n— via BumpBuddy')),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => store.deleteSavedAnswer(s.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
