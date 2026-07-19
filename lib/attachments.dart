import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Copies picked files/photos into the app's private documents directory so
/// records survive even if the original is deleted from the gallery.
/// All methods are safe no-ops on web (attachments are mobile-only in v1).
class Attachments {
  static bool get supported => !kIsWeb;

  static Future<Directory> _recordsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}records');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static Future<({String fileName, String filePath})?> _copyIn(
      String sourcePath, String originalName, String recordId) async {
    final dir = await _recordsDir();
    final name = _sanitize(originalName);
    final dest = '${dir.path}${Platform.pathSeparator}${recordId}_$name';
    await File(sourcePath).copy(dest);
    return (fileName: originalName, filePath: dest);
  }

  /// Take a photo with the camera.
  static Future<({String fileName, String filePath})?> fromCamera(
      String recordId) async {
    if (!supported) return null;
    final shot = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 2400, imageQuality: 88);
    if (shot == null) return null;
    return _copyIn(shot.path, shot.name, recordId);
  }

  /// Pick an image from the gallery.
  static Future<({String fileName, String filePath})?> fromGallery(
      String recordId) async {
    if (!supported) return null;
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 2400, imageQuality: 88);
    if (img == null) return null;
    return _copyIn(img.path, img.name, recordId);
  }

  /// Pick a document (PDF or image).
  static Future<({String fileName, String filePath})?> fromFiles(
      String recordId) async {
    if (!supported) return null;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final f = result?.files.single;
    if (f == null || f.path == null) return null;
    return _copyIn(f.path!, f.name, recordId);
  }

  /// Open an attachment with the system viewer (PDFs etc.).
  static Future<void> open(String filePath) async {
    if (!supported || filePath.isEmpty) return;
    await OpenFilex.open(filePath);
  }

  /// Delete the stored copy (called when a record is deleted).
  static Future<void> delete(String filePath) async {
    if (!supported || filePath.isEmpty) return;
    try {
      final f = File(filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort — never block record deletion on file cleanup.
    }
  }
}
