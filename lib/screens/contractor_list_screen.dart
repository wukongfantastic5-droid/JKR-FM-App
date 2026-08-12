import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/contractor_data.dart';
import '../localization.dart';
import '../services/contractor_service.dart';
import '../services/repo_service.dart';
import '../services/report_saver.dart';

class ContractorListScreen extends StatefulWidget {
  const ContractorListScreen({super.key});

  @override
  State<ContractorListScreen> createState() => _ContractorListScreenState();
}

class _ContractorListScreenState extends State<ContractorListScreen> {
  bool _loading = true;
  bool _dlBusy = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    RepoService.ensureEnv();
    ContractorService.revision.addListener(_onRevision);
    _load();
  }

  @override
  void dispose() {
    ContractorService.revision.removeListener(_onRevision);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await ContractorService.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openEditor({Contractor? contractor}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ContractorEditor(contractor: contractor),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  /// Admin-only: reset a contractor's PM date & uploaded report file
  /// with a single button (date unlocked so the contractor can set again).
  Future<void> _resetContractor(Contractor c) async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Reset ${c.name}?' : 'Reset ${c.name}?'),
        content: Text(eng
            ? 'This will clear the PM date, unlock it, and delete the uploaded report file (if any). The contractor can set a new date again.'
            : 'Ini akan memadam tarikh PM, membuka kunci, dan memadam fail laporan yang dimuat naik (jika ada). Kontraktor boleh tetapkan tarikh baru semula.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Reset' : 'Reset'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
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
    final ok = await ContractorService.resetPm(c);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Reset done ✓' : 'Reset selesai ✓')
          : (eng ? 'Reset failed — retry' : 'Gagal reset — cuba lagi')),
    ));
    if (ok) await _load();
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('lift')) return Icons.elevator_rounded;
    if (t.contains('gondola')) {
      return Icons.precision_manufacturing_rounded;
    }
    if (t.contains('bms')) return Icons.monitor_heart_rounded;
    if (t.contains('fire')) return Icons.fire_extinguisher_rounded;
    if (t.contains('pac') || t.contains('acmv') || t.contains('ac')) {
      return Icons.ac_unit_rounded;
    }
    return Icons.handyman_rounded;
  }

  Color _colorForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('lift')) return const Color(0xFF0D7377);
    if (t.contains('gondola')) return const Color(0xFFF59E0B);
    if (t.contains('bms')) return const Color(0xFF8B5CF6);
    if (t.contains('fire')) return const Color(0xFFEF4444);
    if (t.contains('pac') || t.contains('acmv') || t.contains('ac')) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFF64748B);
  }

  Future<void> _contactWhatsApp(Contractor c, {required bool askReport}) async {
    final eng = LanguageProvider.isEnglish(context);
    if (c.whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Add a WhatsApp number for ${c.name} first'
            : 'Tambah nombor WhatsApp untuk ${c.name} dahulu'),
      ));
      await _openEditor(contractor: c);
      return;
    }
    var phone = c.whatsapp.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);
    if (phone.startsWith('0')) phone = '60${phone.substring(1)}';
    late String msg;
    if (askReport) {
      msg = eng
          ? 'Hi ${c.contact.isNotEmpty ? c.contact : c.name}, your monthly PPM report for ${c.system} has not arrived yet. Could you please send it? Thank you.'
          : 'Assalamualaikum ${c.contact.isNotEmpty ? c.contact : c.name}, laporan PPM bulanan untuk ${c.system} belum diterima. Boleh tolong hantarkan? Terima kasih.';
    }
    if (!askReport && c.visitUnscheduled) {
      msg = eng
          ? 'Hi ${c.contact.isNotEmpty ? c.contact : c.name}, please share your scheduled date & time for this month\'s PPM visit for ${c.system}. Thank you.'
          : 'Assalamualaikum ${c.contact.isNotEmpty ? c.contact : c.name}, boleh beritahu tarikh & masa lawatan PPM bulan ini untuk ${c.system}? Terima kasih.';
    }
    if (!askReport && !c.visitUnscheduled) {
      msg = eng
          ? 'Hi ${c.contact.isNotEmpty ? c.contact : c.name}, could you confirm your PPM visit on ${c.ppmDate}${c.ppmTime.isNotEmpty ? ' at ${c.ppmTime}' : ''} for ${c.system}? Thank you.'
          : 'Assalamualaikum ${c.contact.isNotEmpty ? c.contact : c.name}, boleh sahkan lawatan PPM anda pada ${c.ppmDate}${c.ppmTime.isNotEmpty ? ' jam ${c.ppmTime}' : ''} untuk ${c.system}? Terima kasih.';
    }
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(eng
          ? 'Could not open WhatsApp — check the number'
          : 'Tidak dapat buka WhatsApp — semak nombor'),
    ));
  }

  Future<void> _openReport(Contractor c) async {
    final eng = LanguageProvider.isEnglish(context);
    final url = RepoService.rawUrl(c.reportFile);
    if (url.isEmpty || !await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Could not open the report file'
            : 'Tidak dapat buka fail laporan'),
      ));
    }
  }

  /// Downloads every file under Contractor_Report/ from the repo into
  /// Downloads\FM_Report\Contractor_Report\<Contractor>\<System>\<Date>\...
  Future<void> _downloadAllReports() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() => _dlBusy = true);
    try {
      final files = await ContractorService.downloadAllReports();
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(eng
                ? 'No contractor reports in the repo yet'
                : 'Tiada laporan kontraktor di repo lagi')));
        return;
      }
      final msg = await ReportSaver.save(files);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(eng
                ? 'Contractor reports: $msg'
                : 'Laporan kontraktor: $msg')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(eng
                ? 'Download failed: $e'
                : 'Muat turun gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _dlBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final q = _search.trim().toLowerCase();
    final contractors = ContractorService.entries.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.system.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'List of Contractor' : 'Senarai Kontraktor'),
        actions: [
          IconButton(
            icon: _dlBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            tooltip: eng ? 'Download all contractor reports' : 'Muat turun semua laporan kontraktor',
            onPressed: _dlBusy ? null : _downloadAllReports,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: eng ? 'Search contractor or system…' : 'Cari kontraktor atau sistem…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              })
                          : null,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                Expanded(
                  child: contractors.isEmpty
                      ? Center(
                          child: Text(
                            eng
                                ? 'No contractor matches your search'
                                : 'Tiada kontraktor sepadan carian',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: contractors.length,
                            itemBuilder: (ctx, i) {
                              final c = contractors[i];
                              return _contractorCard(c, eng);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.add_rounded),
        label: Text(eng ? 'Add' : 'Tambah',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _contractorCard(Contractor c, bool eng) {
    final color = _colorForType(c.system);
    final icon = _iconForType(c.system);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(contractor: c),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(c.system,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (c.whatsapp.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.chat_rounded,
                          size: 22, color: Color(0xFF25D366)),
                      tooltip: eng ? 'WhatsApp' : 'WhatsApp',
                      onPressed: () => _contactWhatsApp(c, askReport: false),
                    ),
                  if (c.pmLocked)
                    IconButton(
                      icon: const Icon(Icons.lock_rounded,
                          size: 20, color: Color(0xFF16A34A)),
                      tooltip: eng
                          ? 'PM date locked — reset to change'
                          : 'Tarikh PM dikunci — reset untuk tukar',
                      onPressed: null,
                    ),
                  IconButton(
                    icon: Icon(Icons.restart_alt_rounded,
                        size: 20, color: Colors.orange.shade700),
                    tooltip: eng ? 'Reset PM date & report' : 'Reset tarikh PM & laporan',
                    onPressed: () => _resetContractor(c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    tooltip: eng ? 'Edit / delete' : 'Edit / padam',
                    onPressed: () => _openEditor(contractor: c),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _infoChip(
                    icon: Icons.event_rounded,
                    label: c.visitUnscheduled
                        ? (eng ? 'PM date not set' : 'Tarikh PM belum tetapkan')
                        : '${c.ppmDate}${c.ppmTime.isNotEmpty ? ' · ${c.ppmTime}' : ''}',
                    color: c.visitUnscheduled ? Colors.grey : const Color(0xFF0D7377),
                  ),
                  _infoChip(
                    icon: Icons.description_rounded,
                    label: c.reportSent
                        ? (eng ? 'Report sent' : 'Laporan dihantar')
                        : (eng ? 'Report not sent' : 'Laporan belum dihantar'),
                    color: c.reportSent ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                  ),
                  if (c.hasReportFile)
                    _infoChip(
                      icon: Icons.insert_drive_file_rounded,
                      label: c.reportFileName.isNotEmpty
                          ? c.reportFileName
                          : (eng ? 'Report saved' : 'Laporan disimpan'),
                      color: const Color(0xFF16A34A),
                    ),
                  if (c.location.isNotEmpty)
                    _infoChip(
                      icon: Icons.location_on_rounded,
                      label: c.location,
                      color: const Color(0xFF64748B),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _actionButton(
                      icon: Icons.event_rounded,
                      label: eng ? 'Ask PM date' : 'Tanya tarikh PM',
                      color: const Color(0xFF0D7377),
                      onTap: () => _contactWhatsApp(c, askReport: false),
                    ),
                  const SizedBox(width: 8),
                  if (c.hasReportFile)
                    _actionButton(
                      icon: Icons.visibility_rounded,
                      label: eng ? 'View report' : 'Lihat laporan',
                      color: const Color(0xFF16A34A),
                      onTap: () => _openReport(c),
                    )
                  else if (!c.reportSent)
                    _actionButton(
                      icon: Icons.request_quote_rounded,
                      label: eng ? 'Ask report' : 'Minta laporan',
                      color: const Color(0xFFB45309),
                      onTap: () => _contactWhatsApp(c, askReport: true),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _ContractorEditor extends StatefulWidget {
  final Contractor? contractor;
  const _ContractorEditor({this.contractor});

  @override
  State<_ContractorEditor> createState() => _ContractorEditorState();
}

class _ContractorEditorState extends State<_ContractorEditor> {
  late final Contractor _c;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _locCtrl;
  bool _saving = false;
  late DateTime _reportDate;

  @override
  void initState() {
    super.initState();
    final x = widget.contractor;
    _c = x != null
        ? Contractor(
            id: x.id,
            name: x.name,
            system: x.system,
            contact: x.contact,
            whatsapp: x.whatsapp,
            location: x.location,
            ppmDate: x.ppmDate,
            ppmTime: x.ppmTime,
            reportStatus: x.reportStatus,
            reportFile: x.reportFile,
            reportFileName: x.reportFileName,
            reportUploadedAt: x.reportUploadedAt,
            password: x.password,
            pmLocked: x.pmLocked,
            updatedAt: x.updatedAt,
          )
        : Contractor();
    _reportDate = DateTime.tryParse(x?.ppmDate ?? '') ?? DateTime.now();
    _nameCtrl = TextEditingController(text: _c.name);
    _contactCtrl = TextEditingController(text: _c.contact);
    _waCtrl = TextEditingController(text: _c.whatsapp);
    _locCtrl = TextEditingController(text: _c.location);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _waCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPpmDate(bool eng) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _c.ppmDate.isNotEmpty
          ? DateTime.tryParse(_c.ppmDate) ?? now
          : now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: eng ? 'Monthly PM visit date' : 'Tarikh lawatan PPM bulanan',
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _c.ppmTime.isNotEmpty
          ? _parseTime(_c.ppmTime)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: eng ? 'Visit time' : 'Masa lawatan',
    );
    if (!mounted) return;
    setState(() {
      _c.ppmDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _c.ppmTime = time != null
          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
          : _c.ppmTime;
    });
  }

  TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _save() async {
    final eng = LanguageProvider.isEnglish(context);
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Contractor name required' : 'Nama kontraktor diperlukan')));
      return;
    }
    _c.name = _nameCtrl.text.trim();
    _c.contact = _contactCtrl.text.trim();
    _c.whatsapp = _waCtrl.text.trim();
    _c.location = _locCtrl.text.trim();
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
    final ok = await ContractorService.save(_c);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Saved ✓' : 'Disimpan ✓')
          : (eng ? 'Save failed — retry' : 'Gagal simpan — cuba lagi')),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete contractor?' : 'Padam kontraktor?'),
        content: Text(
            eng ? '"${_c.name}" will be removed permanently.' : '"${_c.name}" akan dipadam kekal.'),
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
    final ok = await ContractorService.remove(_c.id);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Deleted ✓' : 'Dipadam ✓')
          : (eng ? 'Delete failed — retry' : 'Gagal padam — cuba lagi')),
    ));
    if (ok) Navigator.of(context).pop(true);
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

  Future<void> _pickReportImage() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    await _uploadReportBytes(bytes,
        'report_${DateTime.now().millisecondsSinceEpoch}.${file.name.contains('.') ? file.name.split('.').last : 'jpg'}');
  }

  Future<void> _pickReportFile() async {
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
    await _uploadReportBytes(f.bytes!, f.name);
  }

  Future<void> _uploadReportBytes(List<int> bytes, String fileName) async {
    final eng = LanguageProvider.isEnglish(context);
    if (bytes.length > 15 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'File too large (max 15 MB)' : 'Fail terlalu besar (maks 15 MB)')));
      return;
    }
    final safeName = fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final repoPath =
        '${Contractor.reportFolder(_c, _reportDate)}/$safeName';
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
    final path = await ContractorService.uploadReport(
        _c, repoPath, base64Encode(bytes), fileName);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(path != null
          ? (eng ? 'Report saved in database ✓' : 'Laporan disimpan dalam database ✓')
          : (eng ? 'Upload failed — retry' : 'Gagal muat naik — cuba lagi')),
    ));
  }

  Future<void> _openCurrentReport() async {
    final eng = LanguageProvider.isEnglish(context);
    final url = RepoService.rawUrl(_c.reportFile);
    if (url.isEmpty ||
        !await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Could not open the report file' : 'Tidak dapat buka fail laporan')));
    }
  }

  Future<void> _deleteReportFile() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete saved report?' : 'Padam laporan disimpan?'),
        content: Text(
            eng ? 'The report file will be removed from the database.' : 'Fail laporan akan dipadam dari database.'),
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
    final ok = await ContractorService.removeReport(_c);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Report removed ✓' : 'Laporan dipadam ✓')
          : (eng ? 'Remove failed — retry' : 'Gagal padam — cuba lagi')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.contractor == null
              ? (eng ? 'Add Contractor' : 'Tambah Kontraktor')
              : (eng ? 'Edit Contractor' : 'Edit Kontraktor')),
          actions: [
            if (widget.contractor != null)
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                tooltip: eng ? 'Delete' : 'Padam',
                onPressed: _saving ? null : _delete,
              ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(icon: const Icon(Icons.info_rounded), text: eng ? 'Information' : 'Maklumat'),
              const Tab(icon: Icon(Icons.calendar_month_rounded), text: 'PM'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: TabBarView(
            children: [
              _buildInfoTab(eng),
              _buildPmTab(eng),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab(bool eng) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Contractor name / Nama kontraktor',
            hintText: 'e.g. HITACHI',
            prefixIcon: Icon(Icons.business_rounded),
          ),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'System / Sistem',
            prefixIcon: Icon(Icons.category_rounded),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: Contractor.systemGroups.containsKey(_c.system)
                  ? _c.system
                  : Contractor.systemGroups.keys.first,
              isDense: true,
              isExpanded: true,
              items: Contractor.systemGroups.keys.map((s) {
                final name = eng ? s : _systemBM(s);
                return DropdownMenuItem(value: s, child: Text(name));
              }).toList(),
              onChanged: (v) => setState(() => _c.system = v ?? _c.system),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contactCtrl,
          decoration: const InputDecoration(
            labelText: 'Contact person / Orang dihubungi',
            hintText: 'e.g. Encik Ahmad (Service Manager)',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _waCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp number / Nombor WhatsApp',
            hintText: 'e.g. 012 345 6789',
            prefixIcon: Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locCtrl,
          decoration: const InputDecoration(
            labelText: 'Location / Lokasi',
            hintText: 'e.g. Klang, Selangor',
            prefixIcon: Icon(Icons.location_on_rounded),
          ),
        ),
        const SizedBox(height: 26),
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
    );
  }

  Widget _buildPmTab(bool eng) {
    final now = DateTime.now();
    final ppmPassed = _c.ppmDate.isNotEmpty &&
        DateTime.tryParse(_c.ppmDate) != null &&
        DateTime.parse(_c.ppmDate)
            .isBefore(DateTime(now.year, now.month, now.day));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          eng ? 'PM visit date' : 'Tarikh lawatan PM',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _pickPpmDate(eng),
          icon: Icon(_c.ppmDate.isEmpty
              ? Icons.event_available_rounded
              : Icons.event_busy_rounded,
              size: 18, color: const Color(0xFF0D7377)),
          label: Text(
            _c.ppmDate.isEmpty
                ? (eng ? 'Set monthly PM date & time' : 'Tetapkan tarikh & masa PM bulanan')
                : (eng
                    ? 'PM visit: ${_c.ppmDate}${_c.ppmTime.isNotEmpty ? ' · ${_c.ppmTime}' : ''} (tap to change)'
                    : 'Lawatan PM: ${_c.ppmDate}${_c.ppmTime.isNotEmpty ? ' · ${_c.ppmTime}' : ''} (ketuk untuk tukar)'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0D7377),
            side: BorderSide(
                color: const Color(0xFF0D7377).withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (ppmPassed) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 15, color: const Color(0xFFB45309)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  eng
                      ? 'This month\'s PM visit date has passed — ask the contractor.'
                      : 'Tarikh lawatan PM bulan ini telah berlalu — tanya kontraktor.',
                  style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'PM report status / Status laporan PM',
            prefixIcon: Icon(Icons.description_rounded),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _c.reportStatus,
              isDense: true,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                    value: 'pending',
                    child: Text(eng
                        ? 'Pending — not sent yet'
                        : 'Tertunda — belum dihantar')),
                DropdownMenuItem(
                    value: 'sent',
                    child: Text(eng ? 'Sent' : 'Dihantar')),
              ],
              onChanged: (v) => setState(() => _c.reportStatus = v ?? _c.reportStatus),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          eng ? 'Report upload (saved in database)' : 'Muat naik laporan (disimpan dalam database)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                eng ? 'Report month' : 'Bulan laporan',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _pickReportDate,
              icon: const Icon(Icons.event_rounded, size: 16),
              label: Text(
                '${_reportDate.day.toString().padLeft(2, '0')} '
                '${_monthName(_reportDate.month)} ${_reportDate.year}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_c.hasReportFile) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_rounded,
                    color: Color(0xFF16A34A)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_c.reportFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        _c.reportUploadedAt.isEmpty
                            ? ''
                            : (eng
                                ? 'Uploaded ${_c.reportUploadedAt.substring(0, 10)}'
                                : 'Dimuat naik ${_c.reportUploadedAt.substring(0, 10)}'),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _openCurrentReport,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(eng ? 'Open' : 'Buka'),
                ),
                IconButton(
                  onPressed: _saving ? null : _deleteReportFile,
                  icon: const Icon(Icons.delete_rounded,
                      color: Colors.red, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickReportImage,
                icon: const Icon(Icons.image_rounded, size: 18),
                label: Text(eng ? 'Upload image' : 'Muat naik imej',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D7377),
                  side: BorderSide(
                      color: const Color(0xFF0D7377).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickReportFile,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(eng ? 'PDF / Excel / Word' : 'PDF / Excel / Word',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D7377),
                  side: BorderSide(
                      color: const Color(0xFF0D7377).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _saving ? null : _resetPmHere,
          icon: const Icon(Icons.restart_alt_rounded,
              size: 18, color: Colors.orange),
          label: Text(
            eng ? 'Reset PM date & report file' : 'Reset tarikh PM & fail laporan',
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Colors.orange),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 26),
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
    );
  }

  Future<void> _resetPmHere() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Reset ${_c.name}?' : 'Reset ${_c.name}?'),
        content: Text(eng
            ? 'This will clear the PM date, unlock it, and delete the uploaded report file (if any). The contractor can set a new date again.'
            : 'Ini akan memadam tarikh PM, membuka kunci, dan memadam fail laporan yang dimuat naik (jika ada). Kontraktor boleh tetapkan tarikh baru semula.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Reset' : 'Reset'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
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
    final ok = await ContractorService.resetPm(_c);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Reset done ✓' : 'Reset selesai ✓')
          : (eng ? 'Reset failed — retry' : 'Gagal reset — cuba lagi')),
    ));
  }

  String _systemBM(String s) {
    switch (s) {
      case 'Lift': return 'Lif';
      case 'Gondola': return 'Gondola';
      case 'BMS': return 'BMS';
      case 'Fire Fighting System': return 'Sistem Pemadam Kebakaran';
      case 'Precision Air Conditioning (PAC) System': return 'Sistem PAC';
      default: return 'Sistem ACMV';
    }
  }

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m.clamp(1, 12) - 1];
  }
}