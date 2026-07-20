import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pregnancy_math.dart';
import '../store.dart';
import '../weekly_content.dart';
import '../widgets/womb_baby.dart';

/// "Your baby this week" — a large 3D-style illustration that grows with
/// gestational age, plus the week's size, development and tips. Twins show
/// two illustrations side by side.
class BabyViewScreen extends StatelessWidget {
  const BabyViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.profile!;
    final week = PregnancyMath.gaWeeks(p).clamp(4, 40);
    final info = WeeklyContent.forWeek(week);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(p.isTwins ? 'Your babies' : 'Your baby')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                if (p.isTwins)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final b in p.babies)
                        Column(
                          children: [
                            WombBaby(
                                week: week,
                                size: 150,
                                toneIndex: store.babySkinTone),
                            const SizedBox(height: 6),
                            Text(b.displayName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onPrimaryContainer)),
                          ],
                        ),
                    ],
                  )
                else
                  WombBaby(
                      week: week, size: 240, toneIndex: store.babySkinTone),
                const SizedBox(height: 12),
                Text('Week $week',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
                Text('About the size of a ${info.size.toLowerCase()} · ${info.approx}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _toneSelector(context, store),
          const SizedBox(height: 16),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This week',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSecondaryContainer)),
                  const SizedBox(height: 6),
                  Text(info.development,
                      style: TextStyle(color: scheme.onSecondaryContainer)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'A friendly illustration that grows with your weeks — not a medical image of your baby.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toneSelector(BuildContext context, AppStore store) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('Skin tone', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(width: 12),
        for (var i = 0; i < babySkinTones.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => store.setBabySkinTone(i),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: babySkinTones[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: store.babySkinTone == i
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: store.babySkinTone == i ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
