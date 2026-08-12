import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/panduan_data.dart';
import '../data/slang_data.dart';
import '../data/pronunciation_data.dart';
import '../data/fca_data.dart';

class RepoService {
  static String _token = '';
  static String _owner = '';
  static String _repo = '';
  static final bool _debug = true;

  static List<Map<String, dynamic>> _complaints = [];
  static List<Map<String, dynamic>> _solutions = [];
  static List<Map<String, dynamic>> _assets = [];
  static List<Map<String, dynamic>> _fca = [];
  static List<Map<String, dynamic>> _slang = [];
  static Map<String, dynamic> _profile = {'userName': '', 'aiName': 'Juru FM', 'conversationCount': 0};
  static List<Map<String, dynamic>> _pronunciation = [];
  static List<Map<String, dynamic>> _conversations = [];
  static List<Map<String, dynamic>> _technicians = [];
  static String lastHttpError = '';

  /// Ring buffer of the most recent GitHub API calls (method, url, status,
  /// note, response snippet). Shown in System Check so a failing phone can be
  /// diagnosed remotely; persisted to `api_log.json` under the app support dir.
  static final List<Map<String, dynamic>> _apiLog = [];
  static Future<void> _apiLogChain = Future.value();

  static List<Map<String, dynamic>> get apiLogEntries => List.unmodifiable(_apiLog);

  /// Public wrapper so other services (e.g. UpdateService) can record their
  /// HTTP calls into the same log shown in System Check.
  static void logApi(String method, String url, int? status,
          {String note = '', String? body}) =>
      _logApi(method, url, status, note: note, body: body);

  static void _logApi(String method, String url, int? status,
      {String note = '', String? body}) {
    String short = url;
    if (short.startsWith('https://api.github.com')) {
      short = short.substring('https://api.github.com'.length);
    }
    final b = (body == null || body.isEmpty)
        ? ''
        : (body.length > 160 ? body.substring(0, 160) : body);
    _apiLog.add({
      't': DateTime.now().toIso8601String(),
      'm': method,
      'u': short,
      's': status ?? -1,
      'n': note,
      'b': b,
    });
    if (_apiLog.length > 40) _apiLog.removeRange(0, _apiLog.length - 40);
    _apiLogChain = _apiLogChain.then((_) async {
      try {
        final dir = await getApplicationSupportDirectory();
        await File('${dir.path}/api_log.json').writeAsString(jsonEncode(_apiLog));
      } catch (_) {}
    });
  }

  static void _err(String m) {
    lastHttpError = m;
    _log(m);
  }

  static String _statusHint(int code) {
    if (code == 401) return ' (401 — token tidak sah / invalid token)';
    if (code == 403) return ' (403 — rate limit / dilarang)';
    if (code == 404) return ' (404 — fail tidak dijumpai)';
    if (code == 429) return ' (429 — terlalu banyak permintaan)';
    return ' (HTTP $code)';
  }

  static void _log(String msg) {
    if (_debug) debugPrint('[RepoService] $msg');
  }

  /// Fallback so web builds (no .env file) work out of the box against the
  /// live data repo; the token can still be entered via System Check.
  static const String _defaultOwner = 'wukongfantastic5-droid';
  static const String _defaultRepo = 'Database-JKR';

  static Future<void> ensureEnv() async {
    if (_token.isEmpty) _token = dotenv.env['GITHUB_TOKEN'] ?? '';
    if (_owner.isEmpty) _owner = dotenv.env['REPO_OWNER'] ?? '';
    if (_repo.isEmpty) _repo = dotenv.env['REPO_NAME'] ?? '';
    if (_token.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (_token.isEmpty) _token = prefs.getString('repo_token') ?? '';
      if (_owner.isEmpty) _owner = prefs.getString('repo_owner') ?? '';
      if (_repo.isEmpty) _repo = prefs.getString('repo_name') ?? '';
    }
    if (_owner.isEmpty) _owner = _defaultOwner;
    if (_repo.isEmpty) _repo = _defaultRepo;
    _log('Config: token=${_token.isNotEmpty}, owner=$_owner, repo=$_repo');
  }

  /// One connectivity self-test result.
  static Future<Map<String, dynamic>> diagnostics() async {
    final out = <String, dynamic>{};
    await ensureEnv();
    out['hasToken'] = _token.isNotEmpty;
    out['owner'] = _owner;
    out['repo'] = _repo;

    // 1) plain GitHub reachability (no auth dependency).
    try {
      final probe = await http.get(
        Uri.parse('https://api.github.com'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));
      _logApi('PROBE', 'https://api.github.com', probe.statusCode,
          note: 'reachability');
      out['apiReachable'] = probe.statusCode;
    } catch (e) {
      _logApi('PROBE', 'https://api.github.com', null, note: 'reachability err: $e');
      out['apiReachable'] = 'ERR: $e';
    }

    // 2) token validity against the /user endpoint.
    if (_token.isNotEmpty && out['apiReachable'] is int) {
      try {
        final u = await http.get(
          Uri.parse('https://api.github.com/user'),
          headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/vnd.github.v3+json'},
        ).timeout(const Duration(seconds: 10));
        _logApi('PROBE', 'https://api.github.com/user', u.statusCode,
            note: 'token auth');
        out['tokenAuth'] = u.statusCode;
      } catch (e) {
        _logApi('PROBE', 'https://api.github.com/user', null, note: 'auth err: $e');
        out['tokenAuth'] = 'ERR: $e';
      }
    } else {
      out['tokenAuth'] = 'skipped';
    }

    // 3) key data files.
    final files = [
      'ppm_schedule.json', 'pm_status.json', 'spare_parts.json',
      'contractors.json', 'technicians.json', 'complaints.json',
      'me_assets.json', 'maintenance.json',
    ];
    out['files'] = await Future.wait(files.map((f) async {
      final sw = Stopwatch()..start();
      final r = await _readFile(f);
      sw.stop();
      final bytes = (r?['rawBase64'] as String?)?.length ?? 0;
      return <String, dynamic>{
        'file': f,
        'ok': r != null,
        'ms': sw.elapsedMilliseconds,
        'bytes': bytes,
      };
    }));
    out['apiTail'] = _apiLog.reversed.take(6).toList();
    return out;
  }

  static Future<void> setConfig(String token, String owner, String repo) async {
    _token = token;
    _owner = owner;
    _repo = repo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('repo_token', token);
    await prefs.setString('repo_owner', owner);
    await prefs.setString('repo_name', repo);
  }

  static String get currentToken => _token;
  static String get currentOwner => _owner;
  static String get currentRepo => _repo;

  /// Short-lived in-memory cache for content reads (30s TTL) so repeated
  /// loads (e.g. across screens or logins) don't re-hit the GitHub API.
  static final Map<String, List<Object>> _readCache = {};

  static Future<dynamic> readFile(String path) async {
    final hit = _readCache[path];
    if (hit != null &&
        DateTime.now().difference(hit[0] as DateTime).inSeconds < 30) {
      return hit[1];
    }
    final result = await _readFile(path);
    final content = result?['content'];
    if (content != null) _readCache[path] = [DateTime.now(), content];
    return content;
  }

  static void _dropCache(String path) => _readCache.remove(path);

  static Future<bool> writeFile(String path, dynamic data) async {
    await ensureEnv();
    final existing = await _readFile(path);
    final ok = await _writeFile(path, data, sha: existing?['sha'] as String?);
    if (ok) _dropCache(path);
    return ok;
  }

  static List<Map<String, dynamic>> get solutions => _solutions;
  static List<SlangEntry> get slangEntries =>
    _slang.map((s) => SlangEntry.fromJson(s)).toList();

  static Future<Map<String, dynamic>?> _readFile(String path) async {
    if (_owner.isEmpty || _repo.isEmpty) return null;
    final url = 'https://api.github.com/repos/$_owner/$_repo/contents/$path';
    final headers = {
      'Accept': 'application/vnd.github.v3+json',
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        _logApi('GET', url, res.statusCode,
            note: 'read $path', body: res.body);
        _err('_readFile($path) → ${res.statusCode}${_statusHint(res.statusCode)}');
        return null;
      }
      _logApi('GET', url, 200, note: 'read $path');
      lastHttpError = '';
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final raw = (data['content'] as String).replaceAll('\n', '');
      final sha = data['sha'] as String;
      // Try JSON decode; if it fails, it's a raw file (image etc)
      try {
        final content = utf8.decode(base64Decode(raw));
        return {'content': jsonDecode(content), 'sha': sha, 'rawBase64': raw};
      } catch (_) {
        return {'rawBase64': raw, 'sha': sha};
      }
    } catch (e) {
      _logApi('GET', url, null, note: 'read $path error: $e');
      _err('_readFile($path) error: $e');
      return null;
    }
  }

  static Future<String?> readRawFile(String path) async {
    final result = await _readFile(path);
    if (result == null) return null;
    return result['rawBase64'] as String?;
  }

  /// All blob file paths in the repo whose path starts with [rootPrefix]
  /// (e.g. 'PM_Status/'), via the recursive git trees API.
  static Future<List<String>> listAllFiles(String rootPrefix) async {
    if (_owner.isEmpty || _repo.isEmpty) return [];
    final url = 'https://api.github.com/repos/$_owner/$_repo/git/trees/main?recursive=1';
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      _logApi('GET', url, res.statusCode,
          note: 'tree', body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode != 200) {
        _log('listAllFiles($rootPrefix) → ${res.statusCode}');
        return [];
      }
      final tree = ((jsonDecode(res.body) as Map<String, dynamic>)['tree'] as List)
          .cast<Map<String, dynamic>>();
      final out = <String>[];
      for (final t in tree) {
        if (t['type'] != 'blob') continue;
        final path = t['path'] as String? ?? '';
        if (path.startsWith(rootPrefix)) out.add(path);
      }
      return out;
    } catch (e) {
      _log('listAllFiles($rootPrefix) error: $e');
      return [];
    }
  }

  static Future<bool> writeRawFile(String path, String base64Content) async {
    await ensureEnv();
    final existing = await _readFile(path);
    final ok = await _writeRawFile(path, base64Content, sha: existing?['sha'] as String?);
    if (ok) _dropCache(path);
    return ok;
  }

  /// Deletes a file (used when removing an uploaded contractor report etc).
  static Future<bool> deleteFile(String path) async {
    if (_token.isEmpty || _owner.isEmpty || _repo.isEmpty) return false;
    final url = 'https://api.github.com/repos/$_owner/$_repo/contents/$path';
    try {
      final existing = await _readFile(path);
      if (existing == null) return true; // nothing to delete
      final body = <String, dynamic>{
        'message': 'Delete $path',
        'branch': 'main',
        'sha': existing['sha'] as String,
      };
      final res = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      _logApi('DELETE', url, res.statusCode,
          note: 'delete $path', body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode == 200) {
        _dropCache(path);
        return true;
      }
      _log('deleteFile($path) FAILED: ${res.body}');
      return false;
    } catch (e) {
      _logApi('DELETE', url, null, note: 'delete $path error: $e');
      _log('deleteFile($path) error: $e');
      return false;
    }
  }

  /// Direct raw URL for a repo file (used to open uploaded reports in the
  /// browser without auth).
  static String rawUrl(String path) {
    if (_owner.isEmpty || _repo.isEmpty) return '';
    return 'https://raw.githubusercontent.com/$_owner/$_repo/main/$path';
  }

  /// Proves this phone can WRITE to the GitHub repo: creates a tiny scratch
  /// file, then deletes it. Returns a human-readable verdict string. This is
  /// the definitive test for "can't save/attend/close" reports.
  static Future<String> testWrite() async {
    await ensureEnv();
    if (_token.isEmpty || _owner.isEmpty || _repo.isEmpty) {
      return 'no config (token/repo missing in this build)';
    }
    const path = '_debug_ping.json';
    final url = 'https://api.github.com/repos/$_owner/$_repo/contents/$path';
    final headers = {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    };
    Future<http.Response> doPut() => http.put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode({
            'message': 'Debug ping from app',
            'content': base64Encode(utf8.encode(
                '{"ping":true,"ts":"${DateTime.now().toIso8601String()}"}')),
            'branch': 'main',
          }),
        );
    try {
      var res = await doPut();
      // 422 = file already exists without a sha: remove it, then retry.
      if (res.statusCode == 422) {
        _logApi('PUT', url, res.statusCode,
            note: 'ping 422 - cleaning first', body: res.body);
        final existing = await _readFile(path);
        if (existing != null) {
          await http.delete(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'message': 'Debug cleanup',
              'branch': 'main',
              'sha': existing['sha'] as String,
            }),
          );
        }
        res = await doPut();
      }
      _logApi('PUT', url, res.statusCode,
          note: 'ping', body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode != 200 && res.statusCode != 201) {
        _err('testWrite: PUT ${res.statusCode}${_statusHint(res.statusCode)}');
        return 'WRITE FAILED — HTTP ${res.statusCode} (see API log)';
      }
      final content = ((jsonDecode(res.body) as Map<String, dynamic>)['content']
          as Map<String, dynamic>?);
      final sha = content?['sha'] as String?;
      final del = await http.delete(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'message': 'Remove debug ping',
          'branch': 'main',
          'sha': sha,
        }),
      );
      _logApi('DELETE', url, del.statusCode,
          note: 'ping cleanup',
          body: del.statusCode >= 400 ? del.body : null);
      lastHttpError = '';
      return del.statusCode == 200
          ? 'WRITE OK — ping file created & removed'
          : 'WRITE OK, but cleanup returned ${del.statusCode}';
    } catch (e) {
      _logApi('PUT', url, null, note: 'ping error: $e');
      _err('testWrite error: $e');
      return 'WRITE ERROR — $e';
    }
  }

  static Future<bool> _writeRawFile(String path, String base64Content, {String? sha}) async {
    if (_token.isEmpty || _owner.isEmpty || _repo.isEmpty) {
      _err('_writeRawFile($path) skipped — no GitHub config (token/repo missing)');
      return false;
    }
    final url = 'https://api.github.com/repos/$_owner/$_repo/contents/$path';
    try {
      final body = <String, dynamic>{
        'message': 'Update $path',
        'content': base64Content,
        'branch': 'main',
      };
      if (sha != null) body['sha'] = sha;
      final res = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      _logApi('PUT', url, res.statusCode,
          note: 'write $path', body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode == 200 || res.statusCode == 201) {
        lastHttpError = '';
        return true;
      }
      if (res.statusCode == 409 && sha != null) {
        final fresh = await _readFile(path);
        if (fresh != null) {
          body['sha'] = fresh['sha'] as String;
          final retry = await http.put(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_token',
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
          _logApi('PUT', url, retry.statusCode,
              note: 'write $path (409 retry)',
              body: retry.statusCode >= 400 ? retry.body : null);
          if (retry.statusCode == 200 || retry.statusCode == 201) {
            lastHttpError = '';
            return true;
          }
          _err('_writeRawFile($path) retry ${retry.statusCode}${_statusHint(retry.statusCode)}');
          return false;
        }
      }
      _err('_writeRawFile($path) FAILED ${res.statusCode}${_statusHint(res.statusCode)}');
      return false;
    } catch (e) {
      _logApi('PUT', url, null, note: 'write $path error: $e');
      _err('_writeRawFile($path) error: $e');
      return false;
    }
  }

  static Future<bool> _writeFile(String path, dynamic jsonData, {String? sha}) async {
    if (_token.isEmpty || _owner.isEmpty || _repo.isEmpty) {
      _err('_writeFile($path) skipped — no GitHub config (token/repo missing)');
      return false;
    }
    final url = 'https://api.github.com/repos/$_owner/$_repo/contents/$path';
    try {
      final body = <String, dynamic>{
        'message': 'Update $path',
        'content': base64Encode(utf8.encode(jsonEncode(jsonData))),
        'branch': 'main',
      };
      if (sha != null) body['sha'] = sha;

      _log('_writeFile($path) sha=${sha ?? "null"}');
      final res = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      _log('_writeFile($path) → ${res.statusCode}');
      _logApi('PUT', url, res.statusCode,
          note: 'write $path', body: res.statusCode >= 400 ? res.body : null);
      if (res.statusCode == 200 || res.statusCode == 201) {
        lastHttpError = '';
        return true;
      }
      // 409 = sha conflict, retry with fresh sha
      if (res.statusCode == 409 && sha != null) {
        _log('_writeFile($path) 409 conflict, retrying...');
        final fresh = await _readFile(path);
        if (fresh != null) {
          body['sha'] = fresh['sha'] as String;
          final retry = await http.put(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_token',
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          ).timeout(const Duration(seconds: 15));
          _log('_writeFile($path) retry → ${retry.statusCode}');
          _logApi('PUT', url, retry.statusCode,
              note: 'write $path (409 retry)',
              body: retry.statusCode >= 400 ? retry.body : null);
          if (retry.statusCode == 200 || retry.statusCode == 201) {
            lastHttpError = '';
            return true;
          }
          _err('_writeFile($path) retry ${retry.statusCode}${_statusHint(retry.statusCode)}');
          return false;
        }
      }
      _err('_writeFile($path) FAILED ${res.statusCode}${_statusHint(res.statusCode)}');
      return false;
    } catch (e) {
      _logApi('PUT', url, null, note: 'write $path error: $e');
      _err('_writeFile($path) error: $e');
      return false;
    }
  }

  static Future<bool> _writeDataFile(String name, dynamic data) async {
    await ensureEnv();
    if (_token.isEmpty || _owner.isEmpty || _repo.isEmpty) {
      _log('_writeDataFile($name) skipped — no config');
      return false;
    }
    final existing = await _readFile(name);
    return await _writeFile(name, data, sha: existing?['sha'] as String?);
  }

  static Future<void> refresh() async {
    await ensureEnv();
    if (_token.isEmpty || _owner.isEmpty || _repo.isEmpty) return;

    final files = [
      'profile.json', 'slang.json', 'pronunciation.json',
      'solutions.json', 'assets.json', 'fca.json', 'complaints.json', 'conversations.json',
      'technicians.json',
    ];
    final results = await Future.wait(files.map((f) async {
      final r = await _readFile(f);
      return MapEntry(f, r);
    }));
    for (final entry in results) {
      if (entry.value == null) continue;
      switch (entry.key) {
        case 'profile.json':
          _profile = Map<String, dynamic>.from(entry.value!['content'] as Map? ?? {});
        case 'slang.json':
          _slang = _listOf(entry.value!['content']);
        case 'pronunciation.json':
          _pronunciation = _listOf(entry.value!['content']);
        case 'solutions.json':
          _solutions = _listOf(entry.value!['content']);
        case 'assets.json':
          _assets = _listOf(entry.value!['content']);
        case 'fca.json':
          _fca = _listOf(entry.value!['content']);
        case 'complaints.json':
          _complaints = _listOf(entry.value!['content']);
        case 'conversations.json':
          _conversations = _listOf(entry.value!['content']);
        case 'technicians.json':
          _technicians = _listOf(entry.value!['content']);
      }
    }
    _log('refresh done — ${_solutions.length} solutions, ${_assets.length} assets, ${_complaints.length} complaints, ${_conversations.length} conversations');
  }

  /// Tolerates both list- and map-shaped files (some legacy files are grouped
  /// by a key such as 'complaints' or 'items').
  static List<Map<String, dynamic>> _listOf(dynamic v) {
    if (v is List) return List<Map<String, dynamic>>.from(v);
    if (v is Map) {
      for (final key in const ['items', 'complaints', 'tickets', 'data', 'entries']) {
        final sub = v[key];
        if (sub is List) return List<Map<String, dynamic>>.from(sub);
      }
    }
    return [];
  }

  static Future<bool> saveSlang(List<SlangEntry> entries) async {
    _slang = entries.map((e) => e.toJson()).toList();
    return await _writeDataFile('slang.json', _slang);
  }

  static Future<bool> saveComplaint(ComplaintData data, String userId) async {
    _complaints.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': data.name,
      'position': data.position,
      'source': data.source,
      'dateReceived': data.dateReceived,
      'timeReceived': data.timeReceived,
      'systemInvolved': data.systemInvolved,
      'building': data.building,
      'problemType': data.problemType,
      'description': data.description,
      'priority': data.priority,
      'imageBase64List': data.imageBase64List,
      'imageNames': data.imageNames,
      'userId': userId,
      'status': 'open',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return await _writeDataFile('complaints.json', _complaints);
  }

  static Future<bool> saveSolution(String problem, String solution, String userId) async {
    _solutions.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'problem': problem,
      'solution': solution,
      'userId': userId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _log('saveSolution: ${_solutions.length} solutions total');
    return await _writeDataFile('solutions.json', _solutions);
  }

  static Future<bool> saveAsset(String name, String type, String location, String notes, String userId) async {
    _assets.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'type': type,
      'location': location,
      'notes': notes,
      'userId': userId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _log('saveAsset: ${_assets.length} assets total');
    return await _writeDataFile('assets.json', _assets);
  }

  static List<Map<String, dynamic>> getAllAssets() => List.from(_assets);

  static List<FcaItem> get fcaItems => _fca.map((f) => FcaItem.fromJson(f)).toList();

  static Future<bool> updateFcaItem(FcaItem item) async {
    final idx = _fca.indexWhere((f) => f['id'] == item.id);
    if (idx >= 0) {
      _fca[idx] = item.toJson();
    } else {
      _fca.add(item.toJson());
    }
    return await _writeDataFile('fca.json', _fca);
  }

  static Future<bool> saveFcaSolution(FcaItem item, String solutionText) async {
    item.status = 'closed';
    item.solution = solutionText;
    item.solvedAt = DateTime.now().toIso8601String();
    return await updateFcaItem(item);
  }

  static List<Map<String, dynamic>> searchSolutions(String query) {
    final q = query.toLowerCase();
    return _solutions.where((s) =>
      (s['problem'] as String? ?? '').toLowerCase().contains(q) ||
      (s['solution'] as String? ?? '').toLowerCase().contains(q)
    ).toList();
  }

  static List<Map<String, dynamic>> getAllSolutions() => List.from(_solutions);
  static List<Map<String, dynamic>> getComplaints() => List.from(_complaints);

  static List<Map<String, dynamic>> getTechnicians() => List.from(_technicians);

  static Future<bool> saveTechnicians(List<Map<String, dynamic>> technicians) async {
    _technicians = List<Map<String, dynamic>>.from(technicians);
    return await _writeDataFile('technicians.json', _technicians);
  }

  static Map<String, dynamic> get profile => Map.from(_profile);
  static String get aiName => _profile['aiName'] as String? ?? 'Juru FM';

  static Future<bool> saveProfile(Map<String, dynamic> p) async {
    _profile = Map.from(p);
    return await _writeDataFile('profile.json', _profile);
  }

  static Future<bool> updateProfile({String? userName, String? aiName}) async {
    if (userName != null) _profile['userName'] = userName;
    if (aiName != null) _profile['aiName'] = aiName;
    return await _writeDataFile('profile.json', _profile);
  }

  static List<PronunciationCorrection> get pronunciationCorrections =>
    _pronunciation.map((p) => PronunciationCorrection.fromJson(p)).toList();

  static Future<bool> savePronunciationCorrections(List<PronunciationCorrection> corrections) async {
    _pronunciation = corrections.map((c) => c.toJson()).toList();
    return await _writeDataFile('pronunciation.json', _pronunciation);
  }

  static void saveConversation(String userMsg, String aiReply) {
    final now = DateTime.now();
    _conversations.insert(0, {
      'date': now.toIso8601String(),
      'user': userMsg,
      'ai': aiReply.length > 500 ? '${aiReply.substring(0, 500)}...' : aiReply,
    });
    if (_conversations.length > 30) {
      _conversations = _conversations.sublist(0, 30);
    }
  }

  static Future<bool> flushConversations() async {
    return await _writeDataFile('conversations.json', _conversations);
  }

  static String getConversationHistory({int limit = 5}) {
    if (_conversations.isEmpty) return 'Tiada perbualan lepas.';
    final name = aiName;
    final recent = _conversations.take(limit);
    return recent.map((c) {
      final d = DateTime.tryParse(c['date'] as String? ?? '');
      final dateStr = d != null
          ? '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
          : 'tarikh tak diketahui';
      return '[$dateStr] User: ${c['user']} → $name: ${c['ai']}';
    }).join('\n\n');
  }

  static String searchConversations(String query) {
    final q = query.toLowerCase();
    final name = aiName;
    final matches = _conversations.where((c) =>
      (c['user'] as String? ?? '').toLowerCase().contains(q) ||
      (c['ai'] as String? ?? '').toLowerCase().contains(q)
    ).take(3).toList();
    if (matches.isEmpty) return 'Takde perbualan lepas yang sepadan.';
    return matches.map((c) {
      final d = DateTime.tryParse(c['date'] as String? ?? '');
      final dateStr = d != null
          ? '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
          : 'tarikh tak diketahui';
      return '[$dateStr] User tanyo: ${c['user']}\n$name jawab: ${c['ai']}';
    }).join('\n\n');
  }
}
