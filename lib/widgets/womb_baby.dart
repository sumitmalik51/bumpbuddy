import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Warm skin-tone presets (light → deep). Stored per-profile so the
/// illustration can reflect the family; stylised, never photoreal.
const List<Color> babySkinTones = [
  Color(0xFFF6C9A8),
  Color(0xFFE0A579),
  Color(0xFFB77B4E),
  Color(0xFF8A5A34),
];

/// A soft, dimensional illustration of the baby curled in the womb, sized and
/// proportioned by gestational [week]. Original vector art (CustomPaint) —
/// shaded with radial gradients for a 3D-render feel. Not a medical image.
class WombBaby extends StatefulWidget {
  final int week;
  final double size;
  final int toneIndex;
  final bool showWomb;

  const WombBaby({
    super.key,
    required this.week,
    this.size = 120,
    this.toneIndex = 0,
    this.showWomb = true,
  });

  @override
  State<WombBaby> createState() => _WombBabyState();
}

class _WombBabyState extends State<WombBaby>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: BabyPainter(
            week: widget.week,
            tone: babySkinTones[widget.toneIndex.clamp(0, babySkinTones.length - 1)],
            float: Curves.easeInOut.transform(_c.value),
            showWomb: widget.showWomb,
          ),
        ),
      ),
    );
  }
}

class BabyPainter extends CustomPainter {
  final int week;
  final Color tone;
  final double float; // 0..1 eased
  final bool showWomb;

  BabyPainter({
    required this.week,
    required this.tone,
    required this.float,
    required this.showWomb,
  });

  Color _shade(Color base, double amt) => amt >= 0
      ? Color.lerp(base, Colors.white, amt)!
      : Color.lerp(base, Colors.black, -amt)!;

  /// A radial-shaded oval "blob" — the building block that gives the soft
  /// 3D look. [rot] in radians.
  void _blob(Canvas c, Offset center, Size s, double rot, Color base) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rot);
    final rect = Rect.fromCenter(
        center: Offset.zero, width: s.width, height: s.height);
    c.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.95,
          colors: [_shade(base, 0.22), base, _shade(base, -0.18)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    if (showWomb) {
      // Soft womb backdrop.
      final womb = Rect.fromCircle(
          center: Offset(cx, cy), radius: size.width * 0.48);
      canvas.drawCircle(
        Offset(cx, cy),
        size.width * 0.48,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFF7D9E2), const Color(0xFFE7B7C6)],
          ).createShader(womb),
      );
    }

    // Growth: overall scale and head-to-body ratio change with week.
    final w = week.clamp(4, 40);
    final t = (w - 4) / 36.0; // 0 at 4w, 1 at 40w
    final baseR = size.width * 0.5;
    final scale = baseR * (0.42 + 0.5 * t); // grows through pregnancy
    // Big head early, relatively smaller later.
    final headFrac = 0.62 - 0.16 * t;
    // Chubbier body later.
    final bodyH = 1.15 + 0.15 * t;

    // Gentle float (and a touch of rotation) so it feels alive.
    final dy = (float - 0.5) * size.height * 0.05;
    canvas.save();
    canvas.translate(cx, cy + dy);
    canvas.rotate((float - 0.5) * 0.06);

    Offset p(double x, double y) => Offset(x * scale, y * scale);

    // Soft contact shadow under the baby.
    canvas.drawOval(
      Rect.fromCenter(
          center: p(0.05, 0.72), width: scale * 1.4, height: scale * 0.35),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Legs curled up (drawn first, behind torso).
    _blob(canvas, p(0.34, 0.40), Size(scale * 0.72, scale * 0.44),
        -0.15, _shade(tone, -0.04));
    _blob(canvas, p(0.16, 0.60), Size(scale * 0.52, scale * 0.36),
        0.35, _shade(tone, -0.04));

    // Torso, curled (the C-shape of the fetal position).
    _blob(canvas, p(0.06, 0.12), Size(scale * 1.02, scale * bodyH),
        -0.35, tone);

    // Near arm tucked to the chest.
    _blob(canvas, p(-0.02, 0.06), Size(scale * 0.34, scale * 0.6),
        0.7, _shade(tone, 0.04));

    // Head.
    final hd = scale * headFrac * 1.5;
    final headCenter = p(-0.42, -0.5);
    _blob(canvas, headCenter, Size(hd, hd), -0.1, tone);

    // Ear hint.
    _blob(canvas, headCenter + Offset(hd * 0.34, hd * 0.05),
        Size(hd * 0.22, hd * 0.3), 0.0, _shade(tone, -0.05));

    // Closed-eye + soft cheek, only once the face is proportionally readable.
    final eye = Paint()
      ..color = _shade(tone, -0.45)
      ..strokeWidth = math.max(1.2, hd * 0.03)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final eyeC = headCenter + Offset(-hd * 0.16, -hd * 0.02);
    canvas.drawArc(
        Rect.fromCenter(center: eyeC, width: hd * 0.22, height: hd * 0.16),
        0.15,
        math.pi - 0.3,
        false,
        eye);
    // Rosy cheek.
    canvas.drawCircle(
      headCenter + Offset(-hd * 0.05, hd * 0.12),
      hd * 0.1,
      Paint()..color = const Color(0xFFEF9BB0).withValues(alpha: 0.45),
    );

    // Umbilical cord — a soft curl from the belly outward.
    final cord = Path()
      ..moveTo(p(0.2, 0.2).dx, p(0.2, 0.2).dy)
      ..cubicTo(p(0.5, 0.25).dx, p(0.5, 0.25).dy, p(0.55, 0.5).dx,
          p(0.55, 0.5).dy, p(0.42, 0.62).dx, p(0.42, 0.62).dy);
    canvas.drawPath(
      cord,
      Paint()
        ..color = const Color(0xFFE7A9B6)
        ..strokeWidth = scale * 0.06
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(BabyPainter old) =>
      old.float != float ||
      old.week != week ||
      old.tone != tone ||
      old.showWomb != showWomb;
}
