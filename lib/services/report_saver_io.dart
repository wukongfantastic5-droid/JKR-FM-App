import 'dart:convert';
import 'dart:io';

/// Saves the downloaded PM report files (relative path -> base64) into
/// Downloads\FM_Report preserving a clean structure:
/// FM_Report\PM_Status\<Status>\<date>\<System>\<Asset>\files...
class ReportSaver {
  static Future<String> save(Map<String, String> files) async {
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        return 'Cannot find home folder';
      }
      var downloads = Directory('$home\\Downloads');
      if (!downloads.existsSync()) downloads = Directory('$home/Downloads');
      final root = Directory('${downloads.path}\\FM_Report');
      if (root.existsSync()) root.deleteSync(recursive: true);
      root.createSync(recursive: true);

      var ok = 0;
      var fail = 0;
      for (final entry in files.entries) {
        final rel = entry.key.startsWith('/') ? entry.key.substring(1) : entry.key;
        final out = File('${root.path}\\$rel');
        try {
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(base64Decode(entry.value));
          ok++;
        } catch (_) {
          fail++;
        }
      }
      return ok == 0
          ? 'Nothing to save'
          : 'Saved $ok files (${fail > 0 ? '$fail failed, ' : ''}folder: ${root.path})';
    } catch (e) {
      return 'Save error: $e';
    }
  }
}
