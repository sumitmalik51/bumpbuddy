import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Medicines')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add medicine'),
      ),
      body: store.medicines.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medication_outlined, size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Add your iron, calcium, folic acid and any prescribed medicines.\nThey appear on the home screen with daily check-offs.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: store.medicines.length,
              itemBuilder: (context, i) {
                final m = store.medicines[i];
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _openEditor(context, existing: m),
                    leading: CircleAvatar(
                      backgroundColor:
                          m.active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      child: Icon(Icons.medication,
                          color: m.active ? scheme.primary : scheme.outline),
                    ),
                    title: Text(m.name),
                    subtitle: Text([
                      if (m.dose.isNotEmpty) m.dose,
                      m.slots.join(', '),
                      if (!m.active) 'paused',
                    ].join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.deleteMedicine(m.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openEditor(BuildContext context, {Medicine? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MedicineEditor(existing: existing),
    );
  }
}

class _MedicineEditor extends StatefulWidget {
  final Medicine? existing;
  const _MedicineEditor({this.existing});

  @override
  State<_MedicineEditor> createState() => _MedicineEditorState();
}

class _MedicineEditorState extends State<_MedicineEditor> {
  static const allSlots = ['Morning', 'Afternoon', 'Evening', 'Night'];
  static const commonMeds = ['Folic acid', 'Iron', 'Calcium', 'Vitamin D', 'Aspirin', 'Progesterone'];

  late final TextEditingController _name;
  late final TextEditingController _dose;
  late Set<String> _slots;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _dose = TextEditingController(text: e?.dose ?? '');
    _slots = Set.of(e?.slots ?? const ['Morning']);
    _active = e?.active ?? true;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'Add medicine' : 'Edit medicine',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in commonMeds)
                  ChoiceChip(
                    label: Text(m),
                    selected: _name.text == m,
                    onSelected: (_) => setState(() => _name.text = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Medicine name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dose,
              decoration: const InputDecoration(
                  labelText: 'Dose', hintText: 'e.g. 1 tablet, 500 mg'),
            ),
            const SizedBox(height: 16),
            const Text('When?', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in allSlots)
                  FilterChip(
                    label: Text(s),
                    selected: _slots.contains(s),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _slots.add(s);
                      } else if (_slots.length > 1) {
                        _slots.remove(s);
                      }
                    }),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _name.text.trim().isEmpty
                    ? null
                    : () {
                        store.upsertMedicine(Medicine(
                          id: widget.existing?.id ?? store.newId(),
                          name: _name.text.trim(),
                          dose: _dose.text.trim(),
                          slots: allSlots.where(_slots.contains).toList(),
                          active: _active,
                        ));
                        Navigator.pop(context);
                      },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
