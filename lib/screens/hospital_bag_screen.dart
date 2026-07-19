import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';

class HospitalBagScreen extends StatelessWidget {
  const HospitalBagScreen({super.key});

  static const _sections = [
    ('documents', 'Documents', Icons.badge_outlined),
    ('mom', 'For mom', Icons.favorite_outline),
    ('babies', 'For the babies', Icons.child_friendly_outlined),
    ('partner', 'For the partner', Icons.backpack_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final scheme = Theme.of(context).colorScheme;
    final done = store.bagItems.where((b) => b.checked).length;
    final total = store.bagItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital bag'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done / $total'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.isTwins)
            Card(
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Twin checklist: doubled baby items, preemie sizes, and an earlier pack-by date — twins usually arrive before 38 weeks.',
                  style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13),
                ),
              ),
            ),
          for (final (listId, title, icon) in _sections) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  listId == 'babies' && !p.isTwins ? 'For the baby' : title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add item',
                  onPressed: () => _addItem(context, store, listId),
                ),
              ],
            ),
            for (final item in store.bagItems.where((b) => b.listId == listId))
              Card(
                color: scheme.surfaceContainerHigh,
                margin: const EdgeInsets.only(bottom: 6),
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    item.text,
                    style: item.checked
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: scheme.outline)
                        : null,
                  ),
                  value: item.checked,
                  onChanged: (_) => store.toggleBagItem(item.id),
                  secondary: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => store.deleteBagItem(item.id),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _addItem(BuildContext context, AppStore store, String listId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Nursing cover'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) store.addBagItem(listId, v.trim());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                store.addBagItem(listId, controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
