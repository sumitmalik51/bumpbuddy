import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models.dart';
import '../pregnancy_math.dart';
import '../store.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pageController = PageController();
  int _page = 0;

  PregnancyType? _type;
  Chorionicity? _chorionicity;
  bool _ivf = false;
  bool _knowsEdd = true;
  DateTime? _edd;
  DateTime? _lmp;
  final _nickA = TextEditingController();
  final _nickB = TextEditingController();
  final _doctor = TextEditingController();
  final _hospital = TextEditingController();

  static final _fmt = DateFormat('d MMM yyyy');

  @override
  void dispose() {
    _pageController.dispose();
    _nickA.dispose();
    _nickB.dispose();
    _doctor.dispose();
    _hospital.dispose();
    super.dispose();
  }

  int get _pageCount => _type == PregnancyType.twins ? 5 : 4;

  bool get _canContinue => switch (_effectivePage) {
        0 => true,
        1 => _type != null,
        2 => _chorionicity != null, // twins only
        3 => _knowsEdd ? _edd != null : _lmp != null,
        _ => true,
      };

  /// Maps the visual page index to a logical step (chorionicity step is
  /// skipped for singletons).
  int get _effectivePage {
    if (_type == PregnancyType.twins) return _page;
    return _page >= 2 ? _page + 1 : _page;
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    final edd = _knowsEdd ? _edd! : PregnancyMath.eddFromLmp(_lmp!);
    final lmp = _knowsEdd ? PregnancyMath.lmpFromEdd(_edd!) : _lmp!;
    final twins = _type == PregnancyType.twins;
    final profile = PregnancyProfile(
      type: _type!,
      chorionicity: twins ? _chorionicity : null,
      edd: edd,
      lmp: lmp,
      ivf: _ivf,
      babies: twins
          ? [
              Baby(label: 'A', nickname: _nickA.text),
              Baby(label: 'B', nickname: _nickB.text),
            ]
          : [Baby(label: 'A', nickname: _nickA.text)],
      doctorName: _doctor.text.trim(),
      hospitalName: _hospital.text.trim(),
    );
    await context.read<AppStore>().saveProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _welcomePage(),
      _typePage(),
      if (_type == PregnancyType.twins) _chorionicityPage(),
      _datesPage(),
      _detailsPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton(
                        onPressed: _back, icon: const Icon(Icons.arrow_back))
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_page + 1) / _pageCount,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canContinue ? _next : null,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(_page == _pageCount - 1
                      ? context.tr('start_tracking')
                      : context.tr('continue')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageWrap(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _welcomePage() {
    final scheme = Theme.of(context).colorScheme;
    return _pageWrap([
      const SizedBox(height: 24),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.favorite, size: 48, color: scheme.primary),
        ),
      ),
      const SizedBox(height: 24),
      Center(
        child: Text(context.tr('welcome_title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          context.tr('welcome_sub'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
      const SizedBox(height: 32),
      Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('welcome_disclaimer'),
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _typePage() {
    return _pageWrap([
      Text('How many little ones?',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('The whole app adapts to your answer.'),
      const SizedBox(height: 24),
      _bigChoice(
        selected: _type == PregnancyType.singleton,
        icon: Icons.child_care,
        title: 'One baby',
        subtitle: 'Singleton pregnancy',
        onTap: () => setState(() => _type = PregnancyType.singleton),
      ),
      const SizedBox(height: 12),
      _bigChoice(
        selected: _type == PregnancyType.twins,
        icon: Icons.people_alt,
        title: 'Twins',
        subtitle: 'Baby A & Baby B tracked separately, twin-specific schedule',
        onTap: () => setState(() => _type = PregnancyType.twins),
      ),
      const SizedBox(height: 12),
      _bigChoice(
        selected: false,
        enabled: false,
        icon: Icons.groups,
        title: 'Triplets or more',
        subtitle: 'Coming soon',
        onTap: () {},
      ),
    ]);
  }

  Widget _chorionicityPage() {
    return _pageWrap([
      Text('What type of twins?',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
          'This is called chorionicity — whether your twins share a placenta. It\'s usually written on your first-trimester scan report, and it decides how often you\'ll be scanned and when the twins typically arrive.'),
      const SizedBox(height: 24),
      for (final c in Chorionicity.values) ...[
        _bigChoice(
          selected: _chorionicity == c,
          icon: switch (c) {
            Chorionicity.dcda => Icons.looks_two,
            Chorionicity.mcda => Icons.join_left,
            Chorionicity.mcma => Icons.join_full,
            Chorionicity.unknown => Icons.help_outline,
          },
          title: c.shortName,
          subtitle: c.friendly,
          onTap: () => setState(() => _chorionicity = c),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _datesPage() {
    return _pageWrap([
      Text('Your dates', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('IVF pregnancy'),
        subtitle: const Text('Your clinic gives you an exact due date'),
        value: _ivf,
        onChanged: (v) => setState(() {
          _ivf = v;
          if (v) _knowsEdd = true;
        }),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('I know my due date')),
          ButtonSegment(value: false, label: Text('I know my LMP')),
        ],
        selected: {_knowsEdd},
        onSelectionChanged: _ivf
            ? null
            : (s) => setState(() => _knowsEdd = s.first),
      ),
      const SizedBox(height: 16),
      if (_knowsEdd)
        _dateField(
          label: 'Expected due date (EDD)',
          value: _edd,
          first: DateTime.now().subtract(const Duration(days: 30)),
          last: DateTime.now().add(const Duration(days: 300)),
          onPicked: (d) => setState(() => _edd = d),
        )
      else
        _dateField(
          label: 'First day of last period (LMP)',
          value: _lmp,
          first: DateTime.now().subtract(const Duration(days: 310)),
          last: DateTime.now(),
          onPicked: (d) => setState(() => _lmp = d),
        ),
      const SizedBox(height: 16),
      if ((_knowsEdd && _edd != null) || (!_knowsEdd && _lmp != null))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(builder: (context) {
              final edd = _knowsEdd ? _edd! : PregnancyMath.eddFromLmp(_lmp!);
              final lmp = _knowsEdd ? PregnancyMath.lmpFromEdd(_edd!) : _lmp!;
              final gaDays =
                  DateTime.now().difference(PregnancyMath.dateOnly(lmp)).inDays;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are about ${gaDays ~/ 7} weeks + ${gaDays % 7} days',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Due date: ${_fmt.format(edd)}'),
                ],
              );
            }),
          ),
        ),
    ]);
  }

  Widget _detailsPage() {
    final twins = _type == PregnancyType.twins;
    return _pageWrap([
      Text('A few optional details',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('You can change all of this later in Profile.'),
      const SizedBox(height: 24),
      TextField(
        controller: _nickA,
        decoration: InputDecoration(
            labelText: twins ? 'Nickname for Baby A' : 'Baby nickname',
            hintText: twins ? 'e.g. Cherry' : 'e.g. Munchkin'),
      ),
      if (twins) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _nickB,
          decoration: const InputDecoration(
              labelText: 'Nickname for Baby B', hintText: 'e.g. Berry'),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _doctor,
        decoration: const InputDecoration(
            labelText: 'Doctor', hintText: 'Dr. …'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _hospital,
        decoration: const InputDecoration(labelText: 'Hospital / clinic'),
      ),
    ]);
  }

  Widget _bigChoice({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon,
                  size: 32,
                  color: enabled
                      ? (selected ? scheme.primary : scheme.onSurfaceVariant)
                      : scheme.outline),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: enabled ? null : scheme.outline)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: enabled
                                ? scheme.onSurfaceVariant
                                : scheme.outline)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required DateTime first,
    required DateTime last,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: first,
          lastDate: last,
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(value == null ? 'Tap to pick a date' : _fmt.format(value)),
      ),
    );
  }
}
