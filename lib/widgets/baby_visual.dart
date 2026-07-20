import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'womb_baby.dart';

/// Shows the best available baby visual for [week]:
/// a bundled DALL·E-generated illustration (assets/baby/…) if present,
/// otherwise the procedural [WombBaby] fallback. Fully offline either way.
class BabyVisual extends StatelessWidget {
  final int week;
  final double size;
  final int toneIndex;
  final bool twins;

  const BabyVisual({
    super.key,
    required this.week,
    this.size = 120,
    this.toneIndex = 0,
    this.twins = false,
  });

  static const _stages = [8, 12, 16, 20, 24, 28, 32, 36, 40];

  String _assetFor(int w) {
    final nearest = _stages.reduce(
        (a, b) => (w - a).abs() <= (w - b).abs() ? a : b);
    final stage = nearest.toString().padLeft(2, '0');
    return 'assets/baby/${twins ? 'twin_' : ''}week_$stage.jpg';
  }

  Future<String?> _resolve() async {
    final primary = _assetFor(week);
    try {
      await rootBundle.load(primary);
      return primary;
    } catch (_) {}
    // Twin art missing? fall back to the singleton image before the painter.
    if (twins) {
      final single = primary.replaceFirst('twin_', '');
      try {
        await rootBundle.load(single);
        return single;
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fallback =
        WombBaby(week: week, size: size, toneIndex: toneIndex);
    return FutureBuilder<String?>(
      future: _resolve(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(width: size, height: size, child: fallback);
        }
        final asset = snap.data;
        if (asset == null) return fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.12),
          child: Image.asset(asset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback),
        );
      },
    );
  }
}
