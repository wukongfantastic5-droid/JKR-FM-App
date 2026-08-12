import 'package:flutter/foundation.dart' show ValueNotifier;
import 'repo_service.dart';

/// Global online/offline switch stored in the repo (maintenance.json).
/// Online: everyone can log in. Offline: only the admin can log in;
/// everyone else gets a "server under maintenance" notice.
class MaintenanceService {
  static const String file = 'maintenance.json';
  static bool _down = false;

  static final ValueNotifier<bool> isDownNotifier = ValueNotifier<bool>(false);

  static bool get isDown => _down;
  static void _bump() => isDownNotifier.value = _down;

  /// Loads the current maintenance flag from the repo (default online).
  static Future<bool> load() async {
    try {
      await RepoService.ensureEnv();
      final data = await RepoService.readFile(file);
      if (data is Map<String, dynamic>) {
        _down = data['down'] == true;
      } else {
        _down = false;
      }
    } catch (e) {
      _down = false;
    }
    _bump();
    return _down;
  }

  /// Sets the maintenance flag in the repo (admin only). Returns false on
  /// failure so the UI can show an error.
  static Future<bool> setDown(bool down) async {
    final ok = await RepoService.writeFile(file, {'down': down});
    if (ok) {
      _down = down;
      _bump();
    }
    return ok;
  }
}