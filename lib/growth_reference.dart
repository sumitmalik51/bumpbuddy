/// Estimated-fetal-weight percentile reference (grams) by gestational week.
///
/// Source: Hadlock FP, Harrist RB, Martinez-Poyer J. "In utero analysis of
/// fetal growth: a sonographic weight standard." Radiology 1991;181:129-33,
/// as tabulated in the Mikolajczyk et al. global reference presentation
/// (Mercy Perinatal non-customised EFW centile table).
///
/// NOTE: this is a SINGLETON reference — twins commonly track below the
/// singleton 50th centile in the third trimester. Shown for orientation
/// only; plotting/interpretation belongs to the care team.
library;

typedef EfwPercentiles = ({double p10, double p50, double p90});

const Map<int, EfwPercentiles> _hadlockEfw = {
  24: (p10: 582, p50: 678, p90: 775),
  25: (p10: 680, p50: 792, p90: 905),
  26: (p10: 788, p50: 918, p90: 1049),
  27: (p10: 907, p50: 1057, p90: 1207),
  28: (p10: 1037, p50: 1209, p90: 1380),
  29: (p10: 1177, p50: 1372, p90: 1567),
  30: (p10: 1327, p50: 1546, p90: 1766),
  31: (p10: 1485, p50: 1730, p90: 1976),
  32: (p10: 1650, p50: 1923, p90: 2196),
  33: (p10: 1820, p50: 2121, p90: 2423),
  34: (p10: 1994, p50: 2324, p90: 2654),
  35: (p10: 2169, p50: 2528, p90: 2887),
  36: (p10: 2343, p50: 2731, p90: 3119),
  37: (p10: 2513, p50: 2929, p90: 3345),
  38: (p10: 2677, p50: 3120, p90: 3562),
  39: (p10: 2831, p50: 3299, p90: 3767),
  40: (p10: 2972, p50: 3464, p90: 3956),
  41: (p10: 3099, p50: 3611, p90: 4124),
};

/// Linearly interpolated percentiles at a (possibly fractional) gestational
/// week. Returns null outside the tabulated 24–41w range.
EfwPercentiles? efwPercentilesAt(double gaWeeks) {
  if (gaWeeks < 24 || gaWeeks > 41) return null;
  final lo = gaWeeks.floor().clamp(24, 41);
  final hi = gaWeeks.ceil().clamp(24, 41);
  final a = _hadlockEfw[lo]!;
  if (lo == hi) return a;
  final b = _hadlockEfw[hi]!;
  final t = gaWeeks - lo;
  double lerp(double x, double y) => x + (y - x) * t;
  return (
    p10: lerp(a.p10, b.p10),
    p50: lerp(a.p50, b.p50),
    p90: lerp(a.p90, b.p90),
  );
}

/// Approximate percentile position of [efwGrams] at [gaWeeks], as a short
/// human label ("~45th centile", "below 10th", "above 90th"). Null when out
/// of range. Log-linear between tabulated centiles is overkill — a simple
/// piecewise-linear estimate between p10/p50/p90 is honest enough for an
/// orientation label.
String? centileLabelFor(double gaWeeks, double efwGrams) {
  final p = efwPercentilesAt(gaWeeks);
  if (p == null) return null;
  if (efwGrams < p.p10) return 'below the 10th centile (singleton ref)';
  if (efwGrams > p.p90) return 'above the 90th centile (singleton ref)';
  double centile;
  if (efwGrams <= p.p50) {
    centile = 10 + 40 * (efwGrams - p.p10) / (p.p50 - p.p10);
  } else {
    centile = 50 + 40 * (efwGrams - p.p50) / (p.p90 - p.p50);
  }
  return '~${centile.round()}th centile (singleton ref)';
}
