import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';

/// Edit every profile field without resetting app data.
/// Switching singleton <-> twins rebuilds the hospital-bag checklist
/// (the user is warned inline).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late PregnancyType _type;
  late Chorionicity _chorionicity;
  late bool _ivf;
  late DateTime _edd;
  late final TextEditingController _nickA;
  late final TextEditingController _nickB;
  late final TextEditingController _doctor;
  late final TextEditingController _hospital;
  late final PregnancyType _originalType;

  static final _fmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final p = context.read<AppStore>().profile!;
    _type = p.type;
    _originalType = p.type;
    _chorionicity = p.chorionicity ?? Chorionicity.unknown;
    _ivf = p.ivf;
    _edd = p.edd;
    _nickA = TextEditingController(
        text: p.babies.isNotEmpty ? p.babies[0].nickname : '');
    _nickB = TextEditingController(
        text: p.babies.length > 1 ? p.babies[1].nickname : '');
    _doctor = TextEditingController(text: p.doctorName);
    _hospital = TextEditingController(text: p.hospitalName);
  }

  @override
  void dispose() {
    _nickA.dispose();
    _nickB.dispose();
    _doctor.dispose();
    _hospital.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    final old = store.profile!;
    final twins = _type == PregnancyType.twins;
    final typeChanged = _type != _originalType;

    final profile = PregnancyProfile(
      type: _type,
      chorionicity: twins ? _chorionicity : null,
      edd: _edd,
      lmp: PregnancyMath.lmpFromEdd(_edd),
      ivf: _ivf,
      babies: twins
          ? [
              Baby(label: 'A', nickname: _nickA.text),
              Baby(label: 'B', nickname: _nickB.text),
            ]
          : [Baby(label: 'A', nickname: _nickA.text)],
      doctorName: _doctor.text.trim(),
      hospitalName: _hospital.text.trim(),
      createdAt: old.createdAt,
    );
    await store.saveProfile(profile, reseedBag: typeChanged);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final twins = _type == PregnancyType.twins;
    final typeChanged = _type != _originalType;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pregnancy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<PregnancyType>(
            segments: const [
              ButtonSegment(
                  value: PregnancyType.singleton, label: Text('One baby')),
              ButtonSegment(value: PregnancyType.twins, label: Text('Twins')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          if (typeChanged)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Saving will rebuild the hospital-bag checklist for '
                '${twins ? 'twins' : 'one baby'} (custom items are replaced).',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
          if (twins) ...[
            const SizedBox(height: 16),
            Text('Chorionicity',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'From your first-trimester scan report. Scan schedule, timeline and arrival window all adapt to this.',
              style:
                  TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final c in Chorionicity.values)
              Card(
                color: _chorionicity == c
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHigh,
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _chorionicity = c),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.shortName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                c.friendly,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (_chorionicity == c)
                          Icon(Icons.check_circle, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('Dates', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _edd,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 300)),
              );
              if (picked != null) setState(() => _edd = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Expected due date (40-week EDD)',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(_fmt.format(_edd)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Currently ${PregnancyMath.gaLabel(PregnancyProfile(type: _type, edd: _edd, babies: const []))} — LMP ${_fmt.format(PregnancyMath.lmpFromEdd(_edd))}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('IVF pregnancy'),
            value: _ivf,
            onChanged: (v) => setState(() => _ivf = v),
          ),
          const SizedBox(height: 8),
          Text('Names', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nickA,
            decoration: InputDecoration(
                labelText: twins ? 'Nickname for Baby A' : 'Baby nickname'),
          ),
          if (twins) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _nickB,
              decoration:
                  const InputDecoration(labelText: 'Nickname for Baby B'),
            ),
          ],
          const SizedBox(height: 16),
          Text('Care team', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _doctor,
            decoration: const InputDecoration(labelText: 'Doctor'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hospital,
            decoration:
                const InputDecoration(labelText: 'Hospital / clinic'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _save,
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
