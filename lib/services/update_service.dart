import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization.dart';
import 'repo_service.dart';

/// Checks GitHub (app_version.json) for a newer app version and, on Android,
/// downloads the release APK with a live 0-100% progress dialog and launches
/// the system package installer.
class UpdateService {
  static const String _versionFile = 'app_version.json';
  static const String _apkName = 'jkr_fm_guide_update.apk';
  static const String _logFile = 'update_log.json';

  static bool _checking = false;
  static bool _downloading = false;

  /// Real-time telemetry: every phone appends its update events (prompt
  /// shown, download ok/failed + reason, install blocked, etc.) to
  /// update_log.json in the repo so failures can be diagnosed remotely.
  static Future<void> report(String event, String detail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var devId = prefs.getString('device_id');
      if (devId == null) {
        devId = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
            '-${Random().nextInt(0x3FFFFFFF).toRadixString(36)}';
        await prefs.setString('device_id', devId);
      }
      final pi = await PackageInfo.fromPlatform();
      final data = await RepoService.readFile(_logFile);
      var list = data is List
          ? data
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList()
          : <Map<String, dynamic>>[];
      list.add({
        'ts': DateTime.now().toIso8601String(),
        'device': devId,
        'app': '${pi.version}+${pi.buildNumber}',
        'event': event,
        'detail': detail,
      });
      if (list.length > 200) list = list.sublist(list.length - 200);
      await RepoService.writeFile(_logFile, list);
    } catch (e) {
      debugPrint('[UpdateService] report failed: $e');
    }
  }

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Read whatever version the database says we should be on.
  static Future<Map<String, dynamic>?> fetch() async {
    try {
      final data = await RepoService.readFile(_versionFile);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return null;
  }

  /// Latest update_log.json entries (newest first), for the System Check
  /// screen: shows what every phone reported (prompt, download, failures).
  static Future<List<Map<String, dynamic>>> fetchLog() async {
    try {
      final data = await RepoService.readFile(_logFile);
      if (data is List) {
        final entries = data
            .map((e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList()
            .reversed
            .toList();
        return entries.take(6).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Compare installed code vs database code. If older -> prompt to update.
  /// [fromUser] = manual "Check updates" tap (shows "up to date" feedback).
  static Future<void> check(BuildContext context, {bool fromUser = false}) async {
    if (_checking || _downloading) return;
    _checking = true;
    try {
      await RepoService.ensureEnv();
      final latest = await fetch();
      final pi = await PackageInfo.fromPlatform();
      final current = int.tryParse(pi.buildNumber) ?? 0;
      if (latest == null) {
        await report('version_fetch_fail',
            RepoService.lastHttpError.isEmpty
                ? 'app_version.json not found in repo'
                : RepoService.lastHttpError);
        if (fromUser) {
          _toast(context, 'No update info in database',
              'Tiada maklumat kemas kini dalam pangkalan data');
        }
        return;
      }
      final latestCode = latest['code'] is int
          ? latest['code'] as int
          : int.tryParse('${latest['code']}') ?? 0;
      if (latestCode <= current) {
        if (fromUser) {
          _toast(context, 'You have the latest version ($current)',
              'Anda sudah ada versi terkini ($current)');
        }
        return;
      }
      final latestVer = latest['version']?.toString() ?? '$latestCode';
      if (!isAndroid) {
        await _desktopPrompt(context, latestVer, current);
        return;
      }
      final eng = _isEng(context);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.system_update_alt_rounded,
              color: Color(0xFF0D7377), size: 40),
          title: Text(eng ? 'Update available' : 'Kemas kini tersedia'),
          content: Text(
            eng
                ? 'New version $latestVer is ready (you have $current).\n\nDownload & install now?'
                : 'Versi baharu $latestVer sedia (anda ada $current).\n\nMuat turun & pasang sekarang?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'LATER' : 'NANTI'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(eng ? 'UPDATE NOW' : 'KEMAS KINI'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (go == true) {
        await report('update_started', 'current build $current -> $latestVer');
        await _downloadAndInstall(context);
      } else {
        await report('update_prompt', 'current build $current, latest $latestVer');
      }
    } catch (e) {
      _toast(context, 'Update check failed ($e)', 'Semakan kemas kini gagal ($e)');
    } finally {
      _checking = false;
    }
  }

  static bool _isEng(BuildContext context) {
    try {
      return LanguageProvider.isEnglish(context);
    } catch (_) {
      return false;
    }
  }

  /// Windows/desktop: no in-place installer — prompt with a button that opens
  /// the browser at the release's Setup.exe asset.
  static Future<void> _desktopPrompt(
      BuildContext context, String latestVer, int current) async {
    final eng = _isEng(context);
    await report('update_prompt', 'desktop build $current, latest $latestVer');
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded,
            color: Color(0xFF0D7377), size: 40),
        title: Text(eng ? 'Update available' : 'Kemas kini tersedia'),
        content: Text(
          eng
              ? 'New version $latestVer is ready (you have $current).\n\nDownload the new installer?'
              : 'Versi baharu $latestVer sedia (anda ada $current).\n\nMuat turun pemasang baharu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(eng ? 'LATER' : 'NANTI'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(eng ? 'DOWNLOAD' : 'MUAT TURUN'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (go != true) return;
    final url = await _setupDownloadUrl();
    if (url == null) {
      RepoService.lastHttpError =
          'Update: Setup.exe not found on GitHub release — contact admin';
      await report('asset_not_found', 'no Setup.exe asset in last 5 releases');
      _toast(context, 'Installer not found on release — contact admin',
          'Pemasang tidak dijumpai di release — hubungi admin');
      return;
    }
    await report('update_started', 'desktop build $current -> $latestVer');
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      await report(ok ? 'desktop_open' : 'desktop_open_failed', url);
      if (!ok) {
        _toast(context, 'Could not open browser — $url',
            'Tidak dapat buka pelayar — $url');
      }
    } catch (e) {
      await report('desktop_open_failed', '$e');
      _toast(context, 'Could not open browser ($e)',
          'Tidak dapat buka pelayar ($e)');
    }
  }

  /// browser_download_url of the newest Setup.exe asset across recent releases.
  static Future<String?> _setupDownloadUrl() async {
    final owner = RepoService.currentOwner;
    final repo = RepoService.currentRepo;
    final token = RepoService.currentToken;
    if (owner.isEmpty || repo.isEmpty || token.isEmpty) {
      RepoService.lastHttpError =
          'Update: GitHub config missing (token not loaded)';
      return null;
    }
    final url = 'https://api.github.com/repos/$owner/$repo/releases?per_page=5';
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 30));
      RepoService.logApi('UPDATE', url, res.statusCode,
          note: 'find setup asset', body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      for (final rel in list) {
        final assets = (rel as Map<String, dynamic>)['assets'] as List<dynamic>? ?? [];
        for (final a in assets) {
          final m = a as Map<String, dynamic>;
          final name = m['name'] as String? ?? '';
          if (name.toLowerCase().contains('setup')) {
            return m['browser_download_url'] as String? ?? m['url'] as String?;
          }
        }
      }
      return null;
    } catch (e) {
      RepoService.logApi('UPDATE', url, null, note: 'find setup asset error: $e');
      return null;
    }
  }

  static void _toast(BuildContext context, String en, String bm) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_isEng(context) ? en : bm)));
  }

  static Future<void> _downloadAndInstall(BuildContext context) async {
    _downloading = true;
    try {
      final assetId = await _latestAssetId();
      if (assetId == null) {
        RepoService.logApi('UPDATE', 'releases?per_page=5', -1,
            note: 'no APK asset found in recent releases');
        RepoService.lastHttpError =
            'Update: APK not found on GitHub release — contact admin';
        await report('asset_not_found',
            'no jkr_fm_guide.apk asset in last 5 releases');
        _toast(context, 'APK not found on release — contact admin',
            'APK tidak ditemui di release — hubungi admin');
        return;
      }
      final file = await _downloadWithProgress(context, assetId);
      if (!context.mounted || file == null) return;
      final size = await file.length();
      if (size < 1024 * 1024 * 5) {
        // Way below the real APK size: the download is corrupt/incomplete.
        RepoService.lastHttpError =
            'Update: downloaded file too small ($size bytes) — retry';
        await report('download_invalid_size', 'only $size bytes downloaded');
        _toast(context,
            'Downloaded file looks incomplete ($size bytes) — retry',
            'Fail muat turun tidak lengkap ($size bytes) — cuba lagi');
        try {
          await file.delete();
        } catch (_) {}
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(_isEng(context)
              ? 'Download complete — confirm Install in the next screen'
              : 'Muat turun selesai — sahkan Pasang di skrin seterusnya'),
        ));
      final installed =
          await FlutterAppInstaller().installApk(filePath: file.path);
      if (!installed) {
        RepoService.lastHttpError =
            'Update: system installer rejected the APK — allow "Install unknown apps" for this app, then try again';
        await report('install_blocked',
            'installer returned false, apk $size bytes');
        _toast(context,
            'Installer blocked — allow "Install unknown apps" for this app',
            'Pemasang disekat — benarkan "Pasang aplikasi tidak diketahui" untuk aplikasi ini');
      } else {
        await report('install_launch', 'installer started, apk $size bytes');
      }
    } catch (e) {
      RepoService.lastHttpError = 'Update error: $e';
      await report('update_error', '$e');
      _toast(context, 'Update failed ($e)', 'Kemas kini gagal ($e)');
    } finally {
      _downloading = false;
    }
  }

  /// assetId of the newest jkr_fm_guide.apk across recent releases.
  static Future<int?> _latestAssetId() async {
    final owner = RepoService.currentOwner;
    final repo = RepoService.currentRepo;
    final token = RepoService.currentToken;
    if (owner.isEmpty || repo.isEmpty || token.isEmpty) {
      RepoService.lastHttpError =
          'Update: GitHub config missing on this phone (token not loaded)';
      return null;
    }
    final url = 'https://api.github.com/repos/$owner/$repo/releases?per_page=5';
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 30));
      RepoService.logApi('UPDATE', url, res.statusCode,
          note: 'find apk asset',
          body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      for (final rel in list) {
        final assets = (rel as Map<String, dynamic>)['assets'] as List<dynamic>? ?? [];
        for (final a in assets) {
          final m = a as Map<String, dynamic>;
          if ((m['name'] as String? ?? '').endsWith('.apk')) {
            return m['id'] as int?;
          }
        }
      }
      return null;
    } catch (e) {
      RepoService.logApi('UPDATE', url, null, note: 'find apk error: $e');
      return null;
    }
  }

  /// Streams the release asset to disk while a dialog shows 0-100%.
  static Future<File?> _downloadWithProgress(BuildContext context, int assetId) async {
    final owner = RepoService.currentOwner;
    final repo = RepoService.currentRepo;
    final token = RepoService.currentToken;
    final eng = _isEng(context);

    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/$_apkName');
    if (await file.exists()) await file.delete();

    final req = http.Request(
      'GET',
      Uri.parse(
          'https://api.github.com/repos/$owner/$repo/releases/assets/$assetId'),
    )..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/octet-stream',
      });
    final url = req.url.toString();
    RepoService.logApi('UPDATE-DL', url, null, note: 'start download asset $assetId');

    final client = http.Client();
    http.StreamedResponse resp;
    try {
      resp = await client.send(req).timeout(const Duration(seconds: 90));
    } catch (e) {
      RepoService.logApi('UPDATE-DL', url, null, note: 'connect error: $e');
      RepoService.lastHttpError = 'Update download: $e';
      await report('download_connect_error', '$e');
      rethrow;
    }
    RepoService.logApi('UPDATE-DL', url, resp.statusCode,
        note: 'asset download, len=${resp.contentLength ?? "?"}');
    if (resp.statusCode != 200 || context.mounted == false) {
      var snippet = '';
      try {
        final chunks = <int>[];
        await for (final c in resp.stream.take(600)) {
          chunks.addAll(c);
        }
        snippet = utf8.decode(chunks, allowMalformed: true);
      } catch (_) {}
      RepoService.logApi('UPDATE-DL', url, resp.statusCode,
          note: 'download rejected', body: snippet);
      RepoService.lastHttpError =
          'Update download rejected: HTTP ${resp.statusCode}';
      await report('download_rejected',
          'HTTP ${resp.statusCode}${snippet.isNotEmpty ? ' · $snippet' : ''}');
      if (context.mounted) _toast(context,
          'Update download failed (HTTP ${resp.statusCode}) - retry',
          'Muat turun gagal (HTTP ${resp.statusCode}) - cuba lagi');
      return null;
    }

    final total = resp.contentLength ?? 0;
    var received = 0;
    final progress = ValueNotifier<double>(0);
    final pctNotifier = ValueNotifier<String>(
        eng ? '0% · 0 MB / 0 MB' : '0% · 0 MB / 0 MB');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(eng ? 'Downloading update…' : 'Memuat turun kemas kini…'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v.clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.black12,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<String>(
                  valueListenable: pctNotifier,
                  builder: (_, t, __) =>
                      Text(t, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          progress.value = received / total;
          pctNotifier.value =
              '${(received / total * 100).toStringAsFixed(0)}% · '
              '${(received / 1048576).toStringAsFixed(1)} MB / '
              '${(total / 1048576).toStringAsFixed(1)} MB';
        } else {
          pctNotifier.value = '${(received / 1048576).toStringAsFixed(1)} MB';
        }
      }
      await sink.flush();
      await sink.close();
      final got = await file.length();
      if (total > 0 && got != total) {
        RepoService.logApi('UPDATE-DL', url, null,
            note: 'size mismatch: got $got of $total bytes');
        RepoService.lastHttpError =
            'Update download incomplete ($got of $total bytes) — retry';
        await report('download_size_mismatch', 'got $got of $total bytes');
        if (context.mounted) {
          Navigator.of(context).pop();
          _toast(context,
              'Download incomplete ($got of $total bytes) — retry',
              'Muat turun tidak lengkap ($got daripada $total bytes) — cuba lagi');
        }
        try {
          await file.delete();
        } catch (_) {}
        return null;
      }
      RepoService.logApi('UPDATE-DL', url, 200, note: 'downloaded $got bytes');
      if (context.mounted) Navigator.of(context).pop();
      return file;
    } catch (e) {
      RepoService.logApi('UPDATE-DL', url, null, note: 'stream error: $e');
      RepoService.lastHttpError = 'Update download: $e';
      await report('download_stream_error', '$e');
      if (context.mounted) Navigator.of(context).pop();
      _toast(context, 'Download failed ($e)', 'Muat turun gagal ($e)');
      return null;
    } finally {
      client.close();
    }
  }
}