// Generates the BumpBuddy launcher-icon source PNGs into assets/icon/.
// Run: flutter test test/tools/generate_icon_test.dart
// (Also runs harmlessly as part of the normal test suite — output is
// deterministic.)
//
// Design: warm rose→violet gradient; one large white heart (the bump/mom)
// holding two small gradient hearts (the twins). On singleton installs the
// icon still reads simply as "hearts" — deliberately twin-friendly branding.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _roseColor = Color(0xFFC2568A);
const _violetColor = Color(0xFF8A56C2);

Path _heart(Rect r) {
  final w = r.width;
  final h = r.height;
  final x = r.left;
  final y = r.top;
  return Path()
    ..moveTo(x + 0.50 * w, y + 0.35 * h)
    ..cubicTo(x + 0.50 * w, y + 0.26 * h, x + 0.42 * w, y + 0.14 * h,
        x + 0.28 * w, y + 0.14 * h)
    ..cubicTo(x + 0.10 * w, y + 0.14 * h, x + 0.05 * w, y + 0.30 * h,
        x + 0.05 * w, y + 0.36 * h)
    ..cubicTo(x + 0.05 * w, y + 0.56 * h, x + 0.25 * w, y + 0.72 * h,
        x + 0.50 * w, y + 0.90 * h)
    ..cubicTo(x + 0.75 * w, y + 0.72 * h, x + 0.95 * w, y + 0.56 * h,
        x + 0.95 * w, y + 0.36 * h)
    ..cubicTo(x + 0.95 * w, y + 0.30 * h, x + 0.90 * w, y + 0.14 * h,
        x + 0.72 * w, y + 0.14 * h)
    ..cubicTo(x + 0.58 * w, y + 0.14 * h, x + 0.50 * w, y + 0.26 * h,
        x + 0.50 * w, y + 0.35 * h)
    ..close();
}

void _paintGradient(Canvas canvas, Rect rect) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_roseColor, _violetColor],
      ).createShader(rect),
  );
}

/// Draws a pregnant-parent side-profile silhouette (white) with a heart on
/// the bump, centered in [bounds]. Reads as "pregnancy" for any parent —
/// not twin-specific.
void _paintMotif(Canvas canvas, Rect bounds) {
  final s = bounds.width;
  Offset p(double fx, double fy) =>
      Offset(bounds.left + fx * s, bounds.top + fy * s);

  // Body: back on the left, belly bulging to the right, down to the base.
  final body = Path()
    ..moveTo(p(0.37, 0.31).dx, p(0.37, 0.31).dy)
    ..cubicTo(p(0.25, 0.30).dx, p(0.25, 0.30).dy, p(0.22, 0.45).dx,
        p(0.22, 0.45).dy, p(0.25, 0.56).dx, p(0.25, 0.56).dy)
    ..cubicTo(p(0.27, 0.66).dx, p(0.27, 0.66).dy, p(0.20, 0.73).dx,
        p(0.20, 0.73).dy, p(0.26, 0.85).dx, p(0.26, 0.85).dy)
    ..cubicTo(p(0.30, 0.93).dx, p(0.30, 0.93).dy, p(0.46, 0.94).dx,
        p(0.46, 0.94).dy, p(0.51, 0.84).dx, p(0.51, 0.84).dy)
    ..cubicTo(p(0.55, 0.77).dx, p(0.55, 0.77).dy, p(0.52, 0.72).dx,
        p(0.52, 0.72).dy, p(0.61, 0.66).dx, p(0.61, 0.66).dy)
    ..cubicTo(p(0.75, 0.57).dx, p(0.75, 0.57).dy, p(0.75, 0.42).dx,
        p(0.75, 0.42).dy, p(0.585, 0.37).dx, p(0.585, 0.37).dy)
    ..cubicTo(p(0.50, 0.345).dx, p(0.50, 0.345).dy, p(0.42, 0.335).dx,
        p(0.42, 0.335).dy, p(0.37, 0.31).dx, p(0.37, 0.31).dy)
    ..close();

  final headCenter = p(0.40, 0.19);
  final headR = 0.115 * s;

  // Soft shadow for depth.
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.16)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.02 * s);
  canvas.drawPath(body.shift(Offset(0, 0.012 * s)), shadow);
  canvas.drawCircle(
      headCenter.translate(0, 0.012 * s), headR, shadow);

  final white = Paint()..color = Colors.white;
  canvas.drawPath(body, white);
  canvas.drawCircle(headCenter, headR, white);

  // Heart on the bump — the "baby" — in the brand gradient.
  final heartRect = Rect.fromCenter(
      center: p(0.545, 0.52), width: 0.24 * s, height: 0.24 * s);
  canvas.drawPath(
    _heart(heartRect),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_roseColor, _violetColor],
      ).createShader(heartRect),
  );
}

Future<void> _savePng(
    Future<void> Function(Canvas canvas, Rect rect) draw, String path) async {
  final recorder = ui.PictureRecorder();
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  final canvas = Canvas(recorder, rect);
  await draw(canvas, rect);
  final image = await recorder.endRecording().toImage(1024, 1024);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate launcher icon PNGs', () async {
    // Full icon (legacy Android + iOS): gradient + motif.
    await _savePng((canvas, rect) async {
      _paintGradient(canvas, rect);
      _paintMotif(canvas, rect.deflate(0.10 * _size));
    }, 'assets/icon/icon.png');

    // Adaptive background: gradient only.
    await _savePng((canvas, rect) async {
      _paintGradient(canvas, rect);
    }, 'assets/icon/icon_bg.png');

    // Adaptive foreground: motif on transparent, inside the ~66% safe zone.
    await _savePng((canvas, rect) async {
      final safe = Rect.fromCenter(
          center: rect.center, width: 0.62 * _size, height: 0.62 * _size);
      _paintMotif(canvas, safe);
    }, 'assets/icon/icon_fg.png');

    expect(File('assets/icon/icon.png').existsSync(), isTrue);
    expect(File('assets/icon/icon_bg.png').existsSync(), isTrue);
    expect(File('assets/icon/icon_fg.png').existsSync(), isTrue);
  });
}
