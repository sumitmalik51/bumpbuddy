import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final weights = store.weights.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Weight tracker')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Log weight'),
      ),
      body: weights.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_weight_outlined,
                        size: 64, color: scheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Log your weight after each checkup (or weekly).\nYour doctor will guide the healthy range for you.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: weights.length,
              itemBuilder: (context, i) {
                final w = weights[i];
                final prev = i + 1 < weights.length ? weights[i + 1] : null;
                final delta = prev == null ? null : w.kg - prev.kg;
                final week = PregnancyMath.gaWeeks(store.profile!, w.date);
                return Card(
                  color: scheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text('$week w',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary)),
                    ),
                    title: Text('${w.kg.toStringAsFixed(1)} kg'),
                    subtitle: Text(DateFormat('EEE, d MMM yyyy').format(w.date)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (delta != null)
                          Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => store.deleteWeight(w.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _addEntry(BuildContext context, AppStore store) {
    final controller = TextEditingController();
    DateTime date = DateTime.now();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Log weight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Weight (kg)', hintText: 'e.g. 62.5'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('d MMM yyyy').format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 310)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final kg = double.tryParse(controller.text.trim());
                if (kg != null && kg > 20 && kg < 200) {
                  store.addWeight(
                      WeightEntry(id: store.newId(), date: date, kg: kg));
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
