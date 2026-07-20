import 'package:flutter/material.dart';

import '../faq_content.dart';

/// Offline, searchable common-questions screen. Educational only.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final items = q.isEmpty
        ? kFaq
        : kFaq
            .where((f) =>
                f.question.toLowerCase().contains(q) ||
                f.answer.toLowerCase().contains(q) ||
                f.category.toLowerCase().contains(q))
            .toList();
    final categories = <String>[];
    for (final f in items) {
      if (!categories.contains(f.category)) categories.add(f.category);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Common questions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search questions…',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text('No matches for "$_query"',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final cat in categories) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                          child: Text(cat,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary)),
                        ),
                        for (final f in items.where((x) => x.category == cat))
                          Card(
                            color: scheme.surfaceContainerHigh,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: q.isNotEmpty,
                                title: Text(f.question,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5)),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [Text(f.answer)],
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'General information only — it can\'t replace advice from your own doctor.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
