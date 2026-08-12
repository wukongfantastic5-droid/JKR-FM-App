import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import '../data/contractor_data.dart';
import 'repo_service.dart';

/// Contractor store (contractors.json in the GitHub repo).
/// Each contractor has a WhatsApp contact, monthly PM visit date/time and
/// a PM report status so the admin can ping them directly via WhatsApp.
class ContractorService {
  static final bool _debug = true;
  static const String file = Contractor.file;
  static List<Contractor> _entries = [];

  /// Bumped on every load/save so open screens refresh in real time.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void _bump() => revision.value++;
  static void _log(String msg) {
    if (_debug) debugPrint('[Contractor] $msg');
  }

  static List<Contractor> get entries => List.from(_entries);

  static Contractor? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Contractor accounts: username = contractor name (case-insensitive),
  /// password = their (changeable) password, seeded as 123456.
  /// The username may be typed as email type too, e.g. HITACHI@gmail.com.
  static Contractor? contractorLogin(String usernameOrEmail, String password) {
    var q = usernameOrEmail.trim().toLowerCase();
    final at = q.indexOf('@');
    if (at >= 0) q = q.substring(0, at);
    final qNoSpace = q.replaceAll(' ', '');
    for (final e in _entries) {
      final n = e.name.trim().toLowerCase();
      final nNoSpace = n.replaceAll(' ', '');
      final sysNoSpace = e.system.toLowerCase().replaceAll(' ', '');
      final hit = q == n ||
          qNoSpace == nNoSpace ||
          sysNoSpace.contains(qNoSpace);
      if (hit && e.password == password) return e;
    }
    return null;
  }

  /// Seed with the default system contractors on the very first run.
  static Future<List<Contractor>> load() async {
    try {
      final data = await RepoService.readFile(file);
      if (data is List) {
        _entries = data
            .map((e) => Contractor.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _entries = Contractor.seed
            .map((s) => Contractor(
                  name: s['name'] ?? '',
                  system: s['system'] ?? '',
                ))
            .toList();
        await _persist();
      }
    } catch (e) {
      _log('load error: $e');
    }
    _bump();
    return List.from(_entries);
  }

  static Future<bool> save(Contractor c) async {
    final idx = _entries.indexWhere((e) => e.id == c.id);
    c.updatedAt = DateTime.now().toIso8601String();
    if (idx >= 0) {
      _entries[idx] = c;
    } else {
      _entries.add(c);
    }
    return await _persist();
  }

  static Future<bool> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    return await _persist();
  }

  /// Uploads a contractor PM report file into the repo and links it to the
  /// contractor. Returns the repo file path, or null if the upload failed.
  static Future<String?> uploadReport(
    Contractor c,
    String repoPath,
    String base64Content,
    String fileName,
  ) async {
    final ok = await RepoService.writeRawFile(repoPath, base64Content);
    if (!ok) return null;
    c.reportFile = repoPath;
    c.reportFileName = fileName;
    c.reportUploadedAt = DateTime.now().toIso8601String();
    c.reportStatus = 'sent'; // a file in the database = report delivered
    final saved = await save(c);
    return saved ? repoPath : null;
  }

  /// Removes the stored report file (if any) and resets the contractor
  /// report fields back to pending.
  static Future<bool> removeReport(Contractor c) async {
    var ok = true;
    if (c.reportFile.isNotEmpty) {
      ok = await RepoService.deleteFile(c.reportFile);
    }
    c.reportFile = '';
    c.reportFileName = '';
    c.reportUploadedAt = '';
    if (c.reportStatus == 'sent') c.reportStatus = 'pending';
    final saved = await save(c);
    return ok && saved;
  }

  /// Admin-only reset: clears the contractor PM date/time, unlocks it,
  /// and deletes every uploaded report file (if any) from the repo.
  static Future<bool> resetPm(Contractor c) async {
    var ok = true;
    if (c.reportFile.isNotEmpty) {
      ok = await RepoService.deleteFile(c.reportFile);
    }
    c.ppmDate = '';
    c.ppmTime = '';
    c.pmLocked = false;
    c.reportFile = '';
    c.reportFileName = '';
    c.reportUploadedAt = '';
    if (c.reportStatus == 'sent') c.reportStatus = 'pending';
    final saved = await save(c);
    return ok && saved;
  }

  /// Download every report file under Contractor_Report/ from the repo.
  /// Returns map of repo path (without the root) -> base64 content.
  static Future<Map<String, String>> downloadAllReports() async {
    final out = <String, String>{};
    final root = '${Contractor.rootFolder}/';
    final paths = await RepoService.listAllFiles(root);
    for (final p in paths) {
      final b64 = await RepoService.readRawFile(p);
      if (b64 == null) continue;
      out[p.substring(root.length)] = b64;
    }
    return out;
  }

  static Future<bool> _persist() async {
    final ok = await RepoService.writeFile(
      file,
      _entries.map((e) => e.toJson()).toList(),
    );
    _bump();
    return ok;
  }
}