import 'package:bumpbuddy/models.dart';
import 'package:bumpbuddy/pregnancy_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PregnancyProfile profile({
    PregnancyType type = PregnancyType.singleton,
    Chorionicity? chorionicity,
    required DateTime edd,
  }) =>
      PregnancyProfile(
        type: type,
        chorionicity: chorionicity,
        edd: edd,
        babies: [Baby(label: 'A')],
      );

  test('EDD/LMP round-trip is 280 days', () {
    final lmp = DateTime(2026, 1, 1);
    final edd = PregnancyMath.eddFromLmp(lmp);
    expect(edd.difference(lmp).inDays, 280);
    expect(PregnancyMath.lmpFromEdd(edd), lmp);
  });

  test('gestational age counts from LMP', () {
    final p = profile(edd: DateTime.now().add(const Duration(days: 140)));
    // 280 - 140 = 140 days = 20 weeks exactly
    expect(PregnancyMath.gaDays(p), 140);
    expect(PregnancyMath.gaWeeks(p), 20);
    expect(PregnancyMath.trimester(p), 2);
  });

  test('MCDA twins get 2-weekly TTTS surveillance from week 16', () {
    final p = profile(
      type: PregnancyType.twins,
      chorionicity: Chorionicity.mcda,
      edd: DateTime.now().add(const Duration(days: 100)),
    );
    final scans = PregnancyMath.scanSchedule(p)
        .where((s) => s.title.contains('TTTS'))
        .map((s) => s.week)
        .toList();
    expect(scans, [16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36]);
  });

  test('delivery horizon adapts to chorionicity', () {
    final base = DateTime.now().add(const Duration(days: 100));
    expect(PregnancyMath.deliveryGuidance(profile(edd: base)).horizonWeek, 40);
    expect(
        PregnancyMath.deliveryGuidance(profile(
                type: PregnancyType.twins,
                chorionicity: Chorionicity.dcda,
                edd: base))
            .horizonWeek,
        38);
    expect(
        PregnancyMath.deliveryGuidance(profile(
                type: PregnancyType.twins,
                chorionicity: Chorionicity.mcma,
                edd: base))
            .horizonWeek,
        34);
  });

  test('arrival window adapts to chorionicity and maps to real dates', () {
    final lmp = DateTime(2025, 11, 10);
    final edd = PregnancyMath.eddFromLmp(lmp);

    final dcda = profile(
        type: PregnancyType.twins, chorionicity: Chorionicity.dcda, edd: edd);
    expect(PregnancyMath.arrivalWindow(dcda),
        (startWeek: 37, endWeek: 38));
    // 37 weeks after LMP 10 Nov 2025 = 259 days = 27 Jul 2026… verify exact date math
    expect(PregnancyMath.dateAtWeek(dcda, 37),
        lmp.add(const Duration(days: 37 * 7)));

    final mcda = profile(
        type: PregnancyType.twins, chorionicity: Chorionicity.mcda, edd: edd);
    expect(PregnancyMath.arrivalWindow(mcda),
        (startWeek: 36, endWeek: 37));

    final mcma = profile(
        type: PregnancyType.twins, chorionicity: Chorionicity.mcma, edd: edd);
    expect(PregnancyMath.arrivalWindow(mcma),
        (startWeek: 32, endWeek: 34));

    final singleton = profile(edd: edd);
    expect(PregnancyMath.arrivalWindow(singleton),
        (startWeek: 39, endWeek: 40));
  });

  test('profile JSON round-trip', () {
    final p = PregnancyProfile(
      type: PregnancyType.twins,
      chorionicity: Chorionicity.mcda,
      edd: DateTime(2026, 11, 20),
      lmp: DateTime(2026, 2, 13),
      ivf: true,
      babies: [Baby(label: 'A', nickname: 'Cherry'), Baby(label: 'B')],
      doctorName: 'Dr. Rao',
      hospitalName: 'City Hospital',
    );
    final restored = PregnancyProfile.fromJson(p.toJson());
    expect(restored.type, PregnancyType.twins);
    expect(restored.chorionicity, Chorionicity.mcda);
    expect(restored.babies.length, 2);
    expect(restored.babies.first.displayName, 'Cherry');
    expect(restored.babies.last.displayName, 'Baby B');
    expect(restored.ivf, true);
  });
}
