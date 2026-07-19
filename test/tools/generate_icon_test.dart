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

/// Draws the heart motif centered in [bounds].
void _paintMotif(Canvas canvas, Rect bounds, {required bool cutout}) {
  final s = bounds.width;
  final big = Rect.fromLTWH(
      bounds.left + 0.10 * s, bounds.top + 0.10 * s, 0.80 * s, 0.80 * s);

  // Soft shadow behind the big heart.
  canvas.drawPath(
    _heart(big.shift(Offset(0, 0.015 * s))),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.02 * s),
  );
  canvas.drawPath(_heart(big), Paint()..color = Colors.white);

  // Twin hearts nested inside, tilted toward each other.
  void drawTwin(Offset center, double size, double angleDeg, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angleDeg * 3.14159265 / 180);
    final r = Rect.fromCenter(
        center: Offset.zero, width: size, height: size);
    canvas.drawPath(_heart(r), Paint()..color = color);
    canvas.restore();
  }

  final cy = bounds.top + 0.505 * s;
  drawTwin(Offset(bounds.left + 0.39 * s, cy), 0.28 * s, -12,
      cutout ? _roseColor : _roseColor);
  drawTwin(Offset(bounds.left + 0.61 * s, cy), 0.28 * s, 12,
      cutout ? _violetColor : _violetColor);
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
      _paintMotif(canvas, rect.deflate(0.06 * _size), cutout: false);
    }, 'assets/icon/icon.png');

    // Adaptive background: gradient only.
    await _savePng((canvas, rect) async {
      _paintGradient(canvas, rect);
    }, 'assets/icon/icon_bg.png');

    // Adaptive foreground: motif on transparent, inside the ~66% safe zone.
    await _savePng((canvas, rect) async {
      final safe = Rect.fromCenter(
          center: rect.center, width: 0.60 * _size, height: 0.60 * _size);
      _paintMotif(canvas, safe, cutout: false);
    }, 'assets/icon/icon_fg.png');

    expect(File('assets/icon/icon.png').existsSync(), isTrue);
    expect(File('assets/icon/icon_bg.png').existsSync(), isTrue);
    expect(File('assets/icon/icon_fg.png').existsSync(), isTrue);
  });
}
