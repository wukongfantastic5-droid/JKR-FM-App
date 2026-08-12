import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jkr_fm_guide/services/pm_status_service.dart';
import 'package:jkr_fm_guide/services/repo_service.dart';

/// Proves the PM "attend" flow works end-to-end on a real device against the
/// real GitHub repo (same token shipped in the release APK). Reproduces the
/// exact scenario reported by users: a task entry is created locally from the
/// schedule, then a repo load() replaces the in-memory list, then attend()
/// must still find and persist it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PM attend + testWrite against real GitHub', (tester) async {
    await dotenv.load();
    SharedPreferences.setMockInitialValues({});
    await RepoService.ensureEnv();
    final token = RepoService.currentToken;
    // If the assert below fires, the enrolled token is missing in this build.
    expect(token.isNotEmpty, isTrue,
        reason: 'GITHUB_TOKEN must be bundled in the APK');

    // sanity: repo is reachable + token is valid
    final probe = await RepoService.diagnostics();
    expect(probe['apiReachable'], isA<int>(),
        reason: 'api.github.com unreachable from this phone/network: ${probe['apiReachable']}');
    expect(probe['tokenAuth'], isA<int>(),
        reason: 'token auth failed: ${probe['tokenAuth']}');

    // definitive write test (create + delete scratch file)
    final wr = await RepoService.testWrite();
    expect(wr, anyOf(startsWith('WRITE OK'), contains('WRITE OK')),
        reason: 'this phone cannot WRITE to the repo: $wr');

    // --- reproduce the reported attend bug ---
    await PmStatusService.load(); // replaces list with server file (no entry yet)
    final now = DateTime.now();
    final date = now.toIso8601String().substring(0, 10);
    final desc = 'E2E TEST ${now.millisecondsSinceEpoch}';
    final e = PmStatusService.entryFor(
      date: date,
      sys: 'CHILLER',
      item: 'CH-1',
      desc: desc,
    );
    expect(PmStatusService.entries.any((x) => x.id == e.id), isTrue);

    // wait for a poll-style reload that would previously WIPE the new entry
    await PmStatusService.load();

    // the actual handler call the user taps: attend must succeed even though
    // the reload above removed the local entry (old code returned false here)
    final attended = await PmStatusService.attend(e, 'T_E2E', 'E2E Tech');
    expect(attended, isTrue, reason: 'attend returned false');

    // read it back from GitHub to prove the write landed
    final stored = await RepoService.readFile(PmStatusService.file);
    final found = (stored as List?)?.any((x) =>
        x is Map &&
        x['id'] == e.id &&
        x['status'] == 'in_progress' &&
        x['techId'] == 'T_E2E');
    expect(found, isTrue, reason: 'attended entry missing from pm_status.json');

    // cleanup: remove the test entry so it never shows in the real data
    final cur = PmStatusService.entries.firstWhere((x) => x.id == e.id);
    final removed = await PmStatusService.removeEntry(cur);
    expect(removed, isTrue, reason: 'cleanup remove failed');
    // GitHub contents API can serve a stale copy right after a write; poll
    // briefly until the delete is visible.
    var clean = false;
    for (var i = 0; i < 6 && !clean; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final after = await RepoService.readFile(PmStatusService.file);
      clean = !((after as List?)?.any((x) => x is Map && x['id'] == e.id) ?? false);
    }
    expect(clean, isTrue, reason: 'test entry left behind after cleanup');
  }, timeout: const Timeout(Duration(minutes: 3)));
}