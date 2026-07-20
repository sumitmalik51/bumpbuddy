import 'package:bumpbuddy/growth_reference.dart';
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

  test('Hadlock reference interpolates and labels centiles sensibly', () {
    // Exact tabulated week.
    final w36 = efwPercentilesAt(36)!;
    expect(w36.p50, 2731);
    // Interpolation half-way between 35 (2528) and 36 (2731).
    final w355 = efwPercentilesAt(35.5)!;
    expect(w355.p50, closeTo((2528 + 2731) / 2, 0.1));
    // Out of range.
    expect(efwPercentilesAt(20), isNull);
    expect(efwPercentilesAt(42), isNull);
    // The user's real values at 35w6d (~35.86w): A=3030 near/above p90,
    // B=2536 close to the 50th.
    expect(centileLabelFor(35.857, 2536), contains('centile'));
    expect(centileLabelFor(35.857, 500), contains('below the 10th'));
    expect(centileLabelFor(35.857, 4000), contains('above the 90th'));
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
