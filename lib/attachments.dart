import 'dart:io';

import 'package:file_selector/file_selector.dart';
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

  /// Take a photo with the camera (one page at a time).
  static Future<List<({String fileName, String filePath})>> fromCamera(
      String recordId) async {
    if (!supported) return const [];
    final shot = await ImagePicker().pickImage(
        source: ImageSource.camera, maxWidth: 3600, imageQuality: 90);
    if (shot == null) return const [];
    final copied = await _copyIn(shot.path, shot.name, recordId);
    return copied == null ? const [] : [copied];
  }

  /// Pick one or more images from the gallery.
  static Future<List<({String fileName, String filePath})>> fromGallery(
      String recordId) async {
    if (!supported) return const [];
    final images = await ImagePicker()
        .pickMultiImage(maxWidth: 3600, imageQuality: 90);
    final out = <({String fileName, String filePath})>[];
    for (final img in images) {
      final copied = await _copyIn(img.path, img.name, recordId);
      if (copied != null) out.add(copied);
    }
    return out;
  }

  /// Pick one or more documents (PDF or image).
  static Future<List<({String fileName, String filePath})>> fromFiles(
      String recordId) async {
    if (!supported) return const [];
    const group = XTypeGroup(
      label: 'Reports',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['application/pdf', 'image/*'],
    );
    final files = await openFiles(acceptedTypeGroups: const [group]);
    final out = <({String fileName, String filePath})>[];
    for (final f in files) {
      final copied = await _copyIn(f.path, f.name, recordId);
      if (copied != null) out.add(copied);
    }
    return out;
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
