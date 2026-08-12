import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/contractor_data.dart';
import '../localization.dart';
import '../services/auth_service.dart';
import '../services/contractor_service.dart';
import '../services/repo_service.dart';
import 'auth/login_screen.dart';

/// Contractor account dashboard: view their own info, upload monthly PM
/// report files straight into Contractor_Report/<name>/<system>/<date>/,
/// browse files they already uploaded, and change their password in settings.
class ContractorDashboardScreen extends StatefulWidget {
  final Contractor contractor;
  const ContractorDashboardScreen({super.key, required this.contractor});

  @override
  State<ContractorDashboardScreen> createState() =>
      _ContractorDashboardScreenState();
}

class _ContractorDashboardScreenState extends State<ContractorDashboardScreen> {
  late Contractor _c;
  bool _loading = true;
  bool _uploading = false;
  DateTime _reportDate = DateTime.now();
  List<String> _myFiles = [];

  @override
  void initState() {
    super.initState();
    RepoService.ensureEnv();
    ContractorService.revision.addListener(_onRevision);
    _c = widget.contractor;
    final d = DateTime.tryParse(_c.ppmDate);
    if (d != null) _reportDate = d;
    _load();
  }

  @override
  void dispose() {
    ContractorService.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ContractorService.load();
    final fresh = ContractorService.byId(_c.id);
    if (fresh != null && mounted) setState(() => _c = fresh);
    await _listMyFiles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _listMyFiles() async {
    final root = '${Contractor.rootFolder}/${Contractor.folderName(_c.name)}/';
    final paths = await RepoService.listAllFiles(root);
    paths.sort((a, b) => b.compareTo(a));
    if (mounted) setState(() => _myFiles = paths);
  }

  Future<void> _logout() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Logout?' : 'Log keluar?'),
        content: Text(eng
            ? 'Log out of ${_c.name} account?'
            : 'Log keluar dari akaun ${_c.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(eng ? 'Logout' : 'Log keluar')),
        ],
      ),
    );
    if (sure != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('contractor_id');
    await prefs.remove('contractor_name');
    await prefs.remove('user_role_dummy');
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _ContractorAccountScreen(contractor: _c)),
    );
    await _load();
  }

  Future<void> _pickReportDate() async {
    final eng = LanguageProvider.isEnglish(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: eng ? 'Report month' : 'Bulan laporan',
    );
    if (picked != null && mounted) setState(() => _reportDate = picked);
  }

  /// Contractor sets their own monthly PM visit date & time. Once confirmed
  /// and saved it is locked — only the admin can reset it afterwards.
  Future<void> _setPmDate() async {
    final eng = LanguageProvider.isEnglish(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _c.ppmDate.isNotEmpty
          ? DateTime.tryParse(_c.ppmDate) ?? now
          : now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: eng ? 'Your monthly PM visit date' : 'Tarikh lawatan PPM bulanan anda',
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _c.ppmTime.isNotEmpty
          ? _parseTime(_c.ppmTime)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: eng ? 'Visit time' : 'Masa lawatan',
    );
    if (!mounted) return;
    final dateStr =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final timeStr = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : _c.ppmTime;

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Confirm PM visit date?' : 'Sahkan tarikh lawatan PM?'),
        content: Text(eng
            ? 'PM visit for ${_c.name} on $dateStr${timeStr.isNotEmpty ? ' at $timeStr' : ''}.\n\nAfter saving, this date is locked — you cannot change it yourself. Contact the admin to reset.'
            : 'Lawatan PM untuk ${_c.name} pada $dateStr${timeStr.isNotEmpty ? ' jam $timeStr' : ''}.\n\nSelepas disimpan, tarikh ini dikunci — anda tidak boleh menukarnya sendiri. Hubungi admin untuk reset.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Confirm & Save' : 'Sahkan & Simpan'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _uploading = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ),
    );
    _c.ppmDate = dateStr;
    _c.ppmTime = timeStr;
    _c.pmLocked = true;
    final ok = await ContractorService.save(_c);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'PM date saved & locked ✓' : 'Tarikh PM disimpan & dikunci ✓')
          : (eng ? 'Save failed — retry' : 'Gagal simpan — cuba lagi')),
    ));
    await _load();
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _uploadImage() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    await _uploadBytes(bytes,
        'report_${DateTime.now().millisecondsSinceEpoch}.${file.name.contains('.') ? file.name.split('.').last : 'jpg'}');
  }

  Future<void> _uploadFile() async {
    final eng = LanguageProvider.isEnglish(context);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.single;
    if (f.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Could not read the file' : 'Tidak dapat baca fail')));
      return;
    }
    await _uploadBytes(f.bytes!, f.name);
  }

  Future<void> _uploadBytes(List<int> bytes, String fileName) async {
    final eng = LanguageProvider.isEnglish(context);
    if (bytes.length > 15 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng
              ? 'File too large (max 15 MB)'
              : 'Fail terlalu besar (maks 15 MB)')));
      return;
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final repoPath = '${Contractor.reportFolder(_c, _reportDate)}/$safeName';
    setState(() => _uploading = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ),
    );
    final path = await ContractorService.uploadReport(
        _c, repoPath, base64Encode(bytes), fileName);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _uploading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(path != null
          ? (eng ? 'Report saved in database ✓' : 'Laporan disimpan dalam database ✓')
          : (eng ? 'Upload failed — retry' : 'Gagal muat naik — cuba lagi')),
    ));
    if (path != null) await _listMyFiles();
    if (mounted) setState(() {});
  }

  Future<void> _openFile(String path) async {
    final eng = LanguageProvider.isEnglish(context);
    final url = RepoService.rawUrl(path);
    if (url.isEmpty || !await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Could not open the file' : 'Tidak dapat buka fail')));
    }
  }

  Future<void> _deleteFile(String path) async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete this report?' : 'Padam laporan ini?'),
        content: Text(eng
            ? 'The file will be removed from the database.'
            : 'Fail akan dipadam dari database.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Delete' : 'Padam'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await RepoService.deleteFile(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (eng ? 'File deleted ✓' : 'Fail dipadam ✓')
              : (eng ? 'Delete failed — retry' : 'Gagal padam — cuba lagi'))));
    }
    if (ok) await _listMyFiles();
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m.clamp(1, 12) - 1];
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(eng ? 'Contractor Dashboard' : 'Paparan Kontraktor',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: eng ? 'Account settings' : 'Tetapan akaun',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: eng ? 'Logout' : 'Log keluar',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    color: const Color(0xFF0D7377).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business_rounded,
                                  color: const Color(0xFF0D7377)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_c.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800)),
                              ),
                              Icon(Icons.event_rounded,
                                  size: 16, color: const Color(0xFF0D7377)),
                              const SizedBox(width: 6),
                              Text(
                                _c.visitUnscheduled
                                    ? (eng ? 'No PM date' : 'Tiada tarikh PM')
                                    : _c.ppmDate,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_c.system,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700)),
                          if (_c.location.isNotEmpty)
                            Text('📍 ${_c.location}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700)),
                          if (!_c.visitUnscheduled && _c.ppmTime.isNotEmpty)
                            Text(eng
                                ? 'Visit time: ${_c.ppmTime}'
                                : 'Masa lawatan: ${_c.ppmTime}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700)),
                          if (_c.pmLocked)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_rounded,
                                      size: 14, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'LOCKED — admin must reset to change',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF16A34A),
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _c.pmLocked && !_c.visitUnscheduled
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF16A34A)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  eng
                                      ? 'Your PM visit is set: ${_c.ppmDate}${_c.ppmTime.isNotEmpty ? ' at ${_c.ppmTime}' : ''}. It is locked and cannot be changed anymore.'
                                      : 'Lawatan PM anda ditetapkan: ${_c.ppmDate}${_c.ppmTime.isNotEmpty ? ' jam ${_c.ppmTime}' : ''}. Ia dikunci dan tidak boleh diubah lagi.',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _uploading ? null : _setPmDate,
                          icon: const Icon(Icons.event_available_rounded,
                              size: 18, color: Color(0xFF0D7377)),
                          label: Text(
                            eng
                                ? 'Set my PM visit date & time'
                                : 'Tetapkan tarikh & masa lawatan PM saya',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D7377)),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D7377),
                            side: BorderSide(
                                color: const Color(0xFF0D7377)
                                    .withValues(alpha: 0.5)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                  const SizedBox(height: 20),
                  Text(
                    eng ? 'Upload monthly PM report' : 'Muat naik laporan PPM bulanan',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${eng ? 'Folder: ' : 'Folder: '}${Contractor.reportFolder(_c, _reportDate)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          eng ? 'Report month' : 'Bulan laporan',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _uploading ? null : _pickReportDate,
                        icon: const Icon(Icons.event_rounded, size: 16),
                        label: Text(
                          '${_reportDate.day.toString().padLeft(2, '0')} '
                          '${_monthName(_reportDate.month)} ${_reportDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : _uploadImage,
                          icon: const Icon(Icons.image_rounded, size: 18),
                          label: Text(eng ? 'Upload image' : 'Muat naik imej',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D7377),
                            side: BorderSide(
                                color: const Color(0xFF0D7377)
                                    .withValues(alpha: 0.5)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _uploading ? null : _uploadFile,
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text('PDF / Excel / Word',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D7377),
                            side: BorderSide(
                                color: const Color(0xFF0D7377)
                                    .withValues(alpha: 0.5)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    eng ? 'My uploaded reports' : 'Laporan yang dimuat naik',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    eng
                        ? 'Stored automatically in the GitHub database.'
                        : 'Disimpan automatik dalam pangkalan data GitHub.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  if (_myFiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Text(
                        eng
                            ? 'No reports uploaded yet'
                            : 'Tiada laporan dimuat naik lagi',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ..._myFiles.map((path) {
                      final parts = path.split('/');
                      final folder = parts.length >= 2 &&
                              parts[parts.length - 2].isNotEmpty
                          ? parts[parts.length - 2]
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.insert_drive_file_rounded,
                              color: Color(0xFF16A34A)),
                          title: Text(parts.last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(folder,
                              style: const TextStyle(fontSize: 11)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 18),
                                onPressed: () => _openFile(path),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded,
                                    size: 18, color: Colors.red),
                                onPressed: () => _deleteFile(path),
                              ),
                            ],
                          ),
                          onTap: () => _openFile(path),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _ContractorAccountScreen extends StatefulWidget {
  final Contractor contractor;
  const _ContractorAccountScreen({required this.contractor});

  @override
  State<_ContractorAccountScreen> createState() =>
      _ContractorAccountScreenState();
}

class _ContractorAccountScreenState extends State<_ContractorAccountScreen> {
  late final TextEditingController _userCtrl;
  late final TextEditingController _curPassCtrl;
  late final TextEditingController _newPassCtrl;
  late final TextEditingController _confirmCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(text: widget.contractor.name);
    _curPassCtrl = TextEditingController();
    _newPassCtrl = TextEditingController();
    _confirmCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _curPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final eng = LanguageProvider.isEnglish(context);
    final c = widget.contractor;
    if (_curPassCtrl.text != c.password) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng
              ? 'Current password is wrong'
              : 'Kata laluan semasa salah')));
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng
              ? 'New password must be at least 6 characters'
              : 'Kata laluan baru minimum 6 aksara')));
      return;
    }
    if (_newPassCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng
              ? 'New passwords do not match'
              : 'Kata laluan baru tidak sepadan')));
      return;
    }
    setState(() => _saving = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ),
    );
    c.password = _newPassCtrl.text;
    final ok = await ContractorService.save(c);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Password changed ✓' : 'Kata laluan ditukar ✓')
          : (eng ? 'Save failed — retry' : 'Gagal simpan — cuba lagi')),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'Account Settings' : 'Tetapan Akaun')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _userCtrl,
              enabled: false,
              decoration: InputDecoration(
                labelText: eng ? 'Account name (username)' : 'Nama akaun',
                prefixIcon: const Icon(Icons.business_rounded),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              eng
                  ? 'Your username is your contractor name — shown here only.'
                  : 'Nama pengguna anda ialah nama kontraktor — dipaparkan di sini sahaja.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              eng ? 'Change password' : 'Tukar kata laluan',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _curPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password (min 6)',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(eng ? 'Save' : 'Simpan',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}