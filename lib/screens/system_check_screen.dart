import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../localization.dart';
import '../services/repo_service.dart';
import '../services/update_service.dart';

/// Connectivity / database self-test. Shows exactly why GitHub data fails:
/// token present, api.github.com reachability, token validity, per-file reads.
class SystemCheckScreen extends StatefulWidget {
  const SystemCheckScreen({super.key});

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen> {
  Map<String, dynamic>? _report;
  bool _running = false;
  String _writeResult = '';
  bool _writing = false;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _report = null;
    });
    final report = await RepoService.diagnostics();
    if (!mounted) return;
    setState(() {
      _report = report;
      _running = false;
    });
  }

  Future<void> _testWrite() async {
    setState(() {
      _writing = true;
      _writeResult = 'testing...';
    });
    final r = await RepoService.testWrite();
    if (!mounted) return;
    setState(() {
      _writeResult = r;
      _writing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r),
    ));
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  String _reportText() {
    final r = _report!;
    final lines = <String>[
      'JKR FM Guide - System Check',
      'Owner: ${r['owner']} | Repo: ${r['repo']}',
      'Token bundled: ${r['hasToken']}',
      'api.github.com reachable: ${r['apiReachable']}',
      'Token auth (GET /user): ${r['tokenAuth']}',
      '--- data files ---',
      for (final f in (r['files'] as List))
        '${f['file']}: ${f['ok'] ? 'OK' : 'FAIL'} (${f['ms']}ms, ${f['bytes']}B)',
      '---',
      'lastHttpError: ${RepoService.lastHttpError}',
    ];
    return lines.join('\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _reportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(LanguageProvider.isEnglish(context)
          ? 'Report copied'
          : 'Laporan disalin'),
    ));
  }

  Widget _row(String title, String value, {bool ok = true}) {
    final color = ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(value,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'System Check' : 'Penyemakan Sistem')),
      body: _running || r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(eng ? 'GitHub database' : 'Database GitHub', [
                  _row(
                      eng ? 'Token in app build' : 'Token dalam aplikasi',
                      '${r['hasToken']} (${r['owner']}/${r['repo']})',
                      ok: r['hasToken'] == true),
                  _row(
                      eng ? 'api.github.com reachable' : 'api.github.com boleh dicapai',
                      '${r['apiReachable']}',
                      ok: '${r['apiReachable']}'.startsWith('2')),
                  _row(
                      eng ? 'Token authorised' : 'Token disahkan',
                      '${r['tokenAuth']}',
                      ok: '${r['tokenAuth']}'.startsWith('2')),
                ]),
                const SizedBox(height: 12),
                _card(eng ? 'Data files' : 'Fail data', [
                  for (final f in (r['files'] as List))
                    _row(
                        '${f['file']}',
                        f['ok'] == true
                            ? 'OK - ${f['ms']}ms, ${f['bytes']}B'
                            : 'FAILED - check lastHttpError',
                        ok: f['ok'] == true),
                ]),
                const SizedBox(height: 12),
                _card(eng ? 'Last error detail' : 'Perincian ralat terakhir', [
                  SelectableText(
                    RepoService.lastHttpError.isEmpty
                        ? (eng ? '(none - all requests fine)' : '(tiada - semua permintaan ok)')
                        : RepoService.lastHttpError,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ]),
                const SizedBox(height: 12),
                _card(eng ? 'Test write (GitHub)' : 'Ujian tulis (GitHub)', [
                  _row(
                      eng ? 'Can this phone WRITE to the repo?' : 'Boleh telefon ini TULIS ke repo?',
                      _writeResult.isEmpty ? (eng ? 'not run' : 'belum diuji') : _writeResult,
                      ok: _writeResult.startsWith('WRITE OK')),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7377)),
                    onPressed: _writing ? null : _testWrite,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(_writing
                        ? (eng ? 'Testing...' : 'Menguji...')
                        : (eng ? 'Test create + delete file' : 'Ujian cipta + hapus fail')),
                  ),
                ]),
                const SizedBox(height: 12),
                _card(eng ? 'API log (latest)' : 'Log API (terkini)', [
                  ..._apiLogWidgets(),
                ]),
                const SizedBox(height: 12),
                _card(eng ? 'Update log in database' : 'Log kemas kini dalam pangkalan data', [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: UpdateService.fetchLog(),
                    builder: (_, snap) {
                      final entries = snap.data ?? const [];
                      if (entries.isEmpty) {
                        return Text(
                          eng ? '(no entries yet)' : '(belum ada entri)',
                          style: const TextStyle(fontSize: 12.5),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in entries) ...[
                            Text(
                              '${e['ts']} · ${e['app']} · ${e['event']}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${e['detail']} (${e['device']})',
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                _card(eng ? 'App version' : 'Versi aplikasi', [
                  FutureBuilder<Map<String, dynamic>>(
                    future: () async {
                      final pi = await PackageInfo.fromPlatform();
                      return {
                        'db': await UpdateService.fetch(),
                        'installed': '${pi.version}+${pi.buildNumber}',
                      };
                    }(),
                    builder: (_, snap) {
                      final v = (snap.data?['db'] as Map<String, dynamic>?);
                      final ver = v?['version']?.toString() ?? '?';
                      final code = v == null ? '?' : '${v['code'] ?? '?'}';
                      final installed = snap.data?['installed']?.toString() ?? '?';
                      return ButtonBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            eng
                                ? 'App installed: $installed — DB version: $ver (code $code)'
                                : 'Aplikasi dipasang: $installed — Versi DB: $ver (kod $code)',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0D7377)),
                            onPressed: () => UpdateService.check(context,
                                fromUser: true),
                            icon: const Icon(Icons.system_update_alt_rounded,
                                size: 18),
                            label: Text(eng ? 'Check updates' : 'Semak kemas kini'),
                          ),
                        ],
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                _hintBox(eng),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _run,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(eng ? 'Re-run' : 'Jalankan semula'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D7377)),
                        onPressed: _copy,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(eng ? 'Copy report' : 'Salin laporan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _apiLogWidgets() {
    final entries = RepoService.apiLogEntries.reversed.take(30).toList();
    if (entries.isEmpty) {
      return [Text('(no API calls yet)', style: const TextStyle(fontSize: 12))];
    }
    return entries.map((e) {
      final t = (e['t'] as String? ?? '').length >= 19
          ? (e['t'] as String).substring(11, 19)
          : (e['t'] as String? ?? '');
      final ok = (e['s'] as int) >= 200 && (e['s'] as int) < 400;
      final b = (e['b'] as String? ?? '').trim();
      final line =
          '$t ${e['m']} ${e['u']} → ${e['s']}${(e['n'] as String? ?? '').isNotEmpty ? ' (${e['n']})' : ''}';
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 14,
                    color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                const SizedBox(width: 6),
                Expanded(child: Text(line, style: const TextStyle(fontSize: 11.5))),
              ],
            ),
            if (b.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 2),
                child: Text(b,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace')),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _hintBox(bool eng) {
    final failed = RepoService.lastHttpError.isNotEmpty;
    final msgs = <String>[
      if (failed && RepoService.lastHttpError.contains('401'))
        eng
            ? 'Fix: GitHub token inside the APK is invalid. Reinstall the LATEST apk.'
            : 'Penyelesaian: Token GitHub dalam APK tidak sah. Pasang semula apk TERBARU.',
      if (failed && RepoService.lastHttpError.contains('Socket'))
        eng
            ? 'Fix: This phone/network cannot reach api.github.com. Try mobile data, another Wi-Fi, or check the phone date & time (must be "auto").'
            : 'Penyelesaian: Telefon/rangkaian ini tidak dapat capai api.github.com. Cuba data mudah alih, Wi-Fi lain, atau semak tarikh & masa telefon (mesti "automatik").',
      if (!failed)
        eng
            ? 'All checks passed on this test. If other phones still fail, they may be running an OLD apk - send them this new build.'
            : 'Semua pemeriksaan lulus pada ujian ini. Jika telefon lain masih gagal, mungkin mereka guna apk LAMA - hantar binaan baru ini.',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eng ? 'Suggested fix' : 'Penyelesaian dicadangkan',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A5C00))),
          const SizedBox(height: 4),
          for (final m in msgs)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(m,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A5C00))),
            ),
        ],
      ),
    );
  }
}