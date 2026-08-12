/// Web fallback: no local file system, so report saving is not available
/// (the desktop app writes into Downloads).
class ReportSaver {
  static Future<String> save(Map<String, String> files) async {
    return 'Report saving is only available in the desktop app';
  }
}
