import 'models.dart';

/// Gestational-age arithmetic and twins-aware clinical schedules.
/// All schedules are *typical patterns* shown for orientation only —
/// the treating obstetrician's plan always takes precedence.
class PregnancyMath {
  static const int termDays = 280; // 40 weeks from LMP

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime lmpFromEdd(DateTime edd) =>
      dateOnly(edd).subtract(const Duration(days: termDays));

  static DateTime eddFromLmp(DateTime lmp) =>
      dateOnly(lmp).add(const Duration(days: termDays));

  /// Gestational age in days on [on] (defaults to today).
  static int gaDays(PregnancyProfile p, [DateTime? on]) {
    final lmp = p.lmp ?? lmpFromEdd(p.edd);
    return dateOnly(on ?? DateTime.now()).difference(dateOnly(lmp)).inDays;
  }

  static int gaWeeks(PregnancyProfile p, [DateTime? on]) => gaDays(p, on) ~/ 7;

  static String gaLabel(PregnancyProfile p, [DateTime? on]) {
    final d = gaDays(p, on);
    if (d < 0) return 'Before LMP';
    return '${d ~/ 7} weeks + ${d % 7} days';
  }

  static String gaShort(PregnancyProfile p, [DateTime? on]) {
    final d = gaDays(p, on);
    return '${d ~/ 7}w ${d % 7}d';
  }

  static int daysToGo(PregnancyProfile p, [DateTime? on]) =>
      dateOnly(p.edd).difference(dateOnly(on ?? DateTime.now())).inDays;

  static int trimester(PregnancyProfile p, [DateTime? on]) {
    final w = gaWeeks(p, on);
    if (w < 13) return 1;
    if (w < 27) return 2;
    return 3;
  }

  /// Week the timeline should run to, and the typical delivery window text.
  static ({int horizonWeek, String window, String note}) deliveryGuidance(
      PregnancyProfile p) {
    if (!p.isTwins) {
      return (
        horizonWeek: 40,
        window: '39–40 weeks',
        note:
            'Most singleton pregnancies are delivered at full term (39–40 weeks) unless your doctor advises otherwise.'
      );
    }
    return switch (p.chorionicity ?? Chorionicity.unknown) {
      Chorionicity.dcda => (
          horizonWeek: 38,
          window: '37–38 weeks',
          note:
              'Uncomplicated DCDA (di-di) twins are typically delivered around 37–38 weeks.'
        ),
      Chorionicity.mcda => (
          horizonWeek: 37,
          window: '36–37 weeks',
          note:
              'Uncomplicated MCDA (mo-di) twins are typically delivered around 36–37 weeks.'
        ),
      Chorionicity.mcma => (
          horizonWeek: 34,
          window: '32–34 weeks',
          note:
              'MCMA (mo-mo) twins are usually delivered around 32–34 weeks, often after a period of intensive monitoring.'
        ),
      Chorionicity.unknown => (
          horizonWeek: 38,
          window: '36–38 weeks',
          note:
              'Twin delivery timing depends on chorionicity — add it in Profile once your doctor confirms it, and this timeline will adapt.'
        ),
    };
  }

  /// Typical planned-arrival window in completed weeks (inclusive).
  /// Twins: driven by chorionicity. Singleton: 39–40.
  static ({int startWeek, int endWeek}) arrivalWindow(PregnancyProfile p) {
    if (!p.isTwins) return (startWeek: 39, endWeek: 40);
    return switch (p.chorionicity ?? Chorionicity.unknown) {
      Chorionicity.dcda => (startWeek: 37, endWeek: 38),
      Chorionicity.mcda => (startWeek: 36, endWeek: 37),
      Chorionicity.mcma => (startWeek: 32, endWeek: 34),
      Chorionicity.unknown => (startWeek: 36, endWeek: 38),
    };
  }

  /// Calendar date on which [week]+0 gestational weeks is reached.
  static DateTime dateAtWeek(PregnancyProfile p, int week) {
    final lmp = p.lmp ?? lmpFromEdd(p.edd);
    return dateOnly(lmp).add(Duration(days: week * 7));
  }

  /// Typical scan/test milestones, adapted for twins by chorionicity.
  /// Returned as (week, title, detail).
  static List<({int week, String title, String detail})> scanSchedule(
      PregnancyProfile p) {
    final items = <({int week, String title, String detail})>[
      (
        week: 7,
        title: 'Dating / viability scan',
        detail: p.isTwins
            ? 'Confirms the number of babies and heartbeats. For twins, this early scan is also when chorionicity is best determined.'
            : 'Confirms the pregnancy, location and heartbeat, and dates it accurately.'
      ),
      (
        week: 12,
        title: 'NT scan + dual marker (11–13.6 weeks)',
        detail:
            'Nuchal translucency scan with first-trimester screening bloods. For twins, screening is interpreted per baby.'
      ),
      (
        week: 20,
        title: 'Anomaly scan / TIFFA (18–22 weeks)',
        detail:
            'Detailed structural scan of ${p.isTwins ? "each baby" : "the baby"} — heart, brain, spine, limbs, placenta position.'
      ),
      (
        week: 26,
        title: 'OGTT — gestational diabetes screen (24–28 weeks)',
        detail:
            'Glucose tolerance test. ${p.isTwins ? "Twin pregnancies have a higher chance of gestational diabetes, so don't skip this." : ""}'
      ),
      (
        week: 28,
        title: 'Tdap vaccine + anti-D if Rh-negative (27–36 weeks)',
        detail:
            'Whooping-cough vaccine for the baby\'s protection; anti-D injection if your blood group is Rh-negative.'
      ),
    ];

    if (!p.isTwins) {
      items.addAll([
        (
          week: 30,
          title: 'Growth scan (28–32 weeks)',
          detail: 'Checks growth, fluid (AFI) and placenta.'
        ),
        (
          week: 36,
          title: 'Growth/position scan (34–36 weeks)',
          detail: 'Confirms position (cephalic/breech), growth and fluid before term.'
        ),
      ]);
      return items;
    }

    // Twins: chorionicity drives surveillance cadence.
    switch (p.chorionicity ?? Chorionicity.unknown) {
      case Chorionicity.dcda:
        for (final w in [24, 28, 32, 36]) {
          items.add((
            week: w,
            title: 'Twin growth scan',
            detail:
                'DCDA twins: growth scans roughly every 4 weeks from 24 weeks. Doctors compare the babies\' estimated weights — a difference of 20–25% or more gets closer follow-up.'
          ));
        }
      case Chorionicity.mcda:
        for (var w = 16; w <= 36; w += 2) {
          items.add((
            week: w,
            title: 'TTTS surveillance scan',
            detail:
                'MCDA twins share a placenta, so scans every 2 weeks from week 16 watch fluid levels and bladders in both babies to catch twin-to-twin transfusion (TTTS) early.'
          ));
        }
      case Chorionicity.mcma:
        for (var w = 16; w <= 32; w += 2) {
          items.add((
            week: w,
            title: 'Intensive twin surveillance',
            detail:
                'MCMA twins are monitored very closely (scans at least every 2 weeks, often more from 26–28 weeks, sometimes as an inpatient).'
          ));
        }
      case Chorionicity.unknown:
        items.add((
          week: 16,
          title: 'Twin surveillance plan',
          detail:
              'Scan frequency for twins depends on chorionicity (shared placenta or not). Set it in Profile once confirmed and this schedule will fill in.'
        ));
        for (final w in [24, 28, 32, 36]) {
          items.add((
            week: w,
            title: 'Twin growth scan',
            detail: 'Growth comparison of Baby A and Baby B.'
          ));
        }
    }
    return items;
  }
}
