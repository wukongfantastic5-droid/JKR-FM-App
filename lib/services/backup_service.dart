import 'dart:convert';
import 'dart:typed_data';

import 'repo_service.dart';
import 'zip_writer.dart';

/// Full database backup: downloads every blob in the repository and packs it
/// into a single STORE ZIP archive (same writer as the docx/xlsx exporters).
class BackupService {
  /// Returns the packed ZIP, or null when nothing could be collected.
  static Future<Uint8List?> collectAll() async {
    final paths = await RepoService.listAllFiles('');
    if (paths.isEmpty) return null;
    final files = <String, List<int>>{};
    for (final p in paths) {
      final b64 = await RepoService.readRawFile(p);
      if (b64 == null) continue;
      try {
        files[p] = base64Decode(b64);
      } catch (_) {
        files[p] = b64.codeUnits;
      }
    }
    if (files.isEmpty) return null;
    return ZipWriter.store(files);
  }
}