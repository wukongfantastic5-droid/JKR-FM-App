import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization.dart';
import '../services/repair_service.dart';
import '../services/repair_docx.dart';
import '../services/contractor_service.dart';
import '../data/contractor_data.dart';

/// "Prepare Documents" workspace for the Repair Guide (admin).
/// Case list + full workflow: incident report, contractor PPM report,
/// suggestion & budget request, submit -> approval -> work permit ->
/// execute repair -> work result report with images.
class RepairDocScreen extends StatefulWidget {
  const RepairDocScreen({super.key});

  @override
  State<RepairDocScreen> createState() => _RepairDocScreenState();
}

class _RepairDocScreenState extends State<RepairDocScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await RepairService.load();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newCase() async {
    final id = await RepairService.nextId();
    final c = RepairCase(id: id, createdAt: RepairService.todayStr());
    RepairService.cases
      ..add(c)
      ..sort((a, b) => b.id.compareTo(a.id));
    if (mounted) {
      await _open(c);
      setState(() {});
    }
  }

  Future<void> _open(RepairCase c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RepairCaseEditorScreen(caseId: c.id)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteCase(RepairCase c) async {
    final eng = LanguageProvider.isEnglish(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Delete case ${c.id}?' : 'Padam kes ${c.id}?'),
        content: Text(eng
            ? 'All generated documents of this case will be removed from the database.'
            : 'Semua dokumen yang dijana untuk kes ini akan dipadam dari database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(eng ? 'Cancel' : 'Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(eng ? 'Delete' : 'Padam', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    RepairService.cases.removeWhere((x) => x.id == c.id);
    await RepairService.persist();
    if (mounted) setState(() {});
  }

  Future<void> _templateManager() async {
    final eng = LanguageProvider.isEnglish(context);
    await RepairService.loadTemplates();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, color: Color(0xFF0D7377)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eng ? 'Template Sheets (reference)' : 'Helaian Templat (rujukan)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0D7377)),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  eng
                      ? 'Upload your own template sheets (with company logo) as reference. They are saved in the database under Templates/RepairGuide.'
                      : 'Muat naik helaian templat anda sendiri (dengan logo syarikat) sebagai rujukan. Disimpan dalam database di bawah Templates/RepairGuide.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D7377)),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(eng ? 'Upload Template Sheet' : 'Muat Naik Helaian Templat'),
                    onPressed: () => _uploadTemplate(ctx, eng),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: RepairService.templates.isEmpty
                    ? Center(
                        child: Text(
                          eng ? 'No templates uploaded yet' : 'Tiada templat dimuat naik lagi',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: RepairService.templates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx2, i) {
                          final path = RepairService.templates[i];
                          final name = path.split('/').last;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D7377).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description_rounded, size: 16, color: Color(0xFF0D7377)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  tooltip: eng ? 'Open' : 'Buka',
                                  onPressed: () => launchUrl(
                                    Uri.parse(RepairService.templateUrl(path)),
                                    mode: LaunchMode.platformDefault,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                  tooltip: eng ? 'Delete' : 'Padam',
                                  onPressed: () async {
                                    await RepairService.deleteTemplate(path);
                                    if (ctx2.mounted) setState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadTemplate(BuildContext ctx, bool eng) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'doc', 'xlsx', 'xls', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    if (f.bytes!.isEmpty) return;
    if (f.name.isEmpty || !f.name.contains('.')) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(eng ? 'Template name is invalid' : 'Nama templat tidak sah'),
        ));
      }
      return;
    }
    final ok = await RepairService.uploadTemplate(f.name, f.bytes!);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(ok
            ? (eng ? 'Template saved in database' : 'Templat disimpan dalam database')
            : (eng ? 'Upload failed' : 'Muat naik gagal')),
      ));
      setState(() {});
    }
  }

  String _statusLabel(RepairStatus s, bool eng) {
    const m = {
      RepairStatus.draft: ('Draft', 'Draf'),
      RepairStatus.submitted: ('Submitted', 'Dihantar'),
      RepairStatus.approved: ('Approved', 'Diluluskan'),
      RepairStatus.rejected: ('Rejected', 'Ditolak'),
      RepairStatus.permit: ('Work Permit Stage', 'Peringkat Permit Kerja'),
      RepairStatus.executing: ('Executing Repair', 'Sedang Menjalankan Pembaikan'),
      RepairStatus.completed: ('Completed', 'Selesai'),
    };
    return eng ? m[s]!.$1 : m[s]!.$2;
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Prepare Documents' : 'Sedia Dokumen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_rounded),
            tooltip: eng ? 'Template sheets' : 'Helaian templat',
            onPressed: _templateManager,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RepairService.cases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF0D7377)),
                      const SizedBox(height: 12),
                      Text(
                        eng ? 'No repair cases yet' : 'Tiada kes pembaikan lagi',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eng ? 'Tap + to start the repair document workflow' : 'Tekan + untuk memulakan aliran dokumen pembaikan',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: RepairService.cases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final c = RepairService.cases[i];
                    final Color statusColor = switch (c.status) {
                      RepairStatus.draft => Colors.grey,
                      RepairStatus.submitted => Colors.orange,
                      RepairStatus.approved => Colors.green,
                      RepairStatus.rejected => Colors.red,
                      RepairStatus.permit => Colors.indigo,
                      RepairStatus.executing => Colors.teal,
                      RepairStatus.completed => const Color(0xFF0D7377),
                    };
                    return InkWell(
                      onTap: () => _open(c),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.id,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0D7377)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _statusLabel(c.status, eng),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${c.system.isNotEmpty ? c.system : (eng ? '(no system)' : '(tiada sistem)')}'
                              '${c.building.isNotEmpty ? ' — ${c.building}' : ''}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
Row(
                    children: [
                      _miniCheck(eng, c.incidentComplete, 'Incident' , 'Insiden'),
                      const SizedBox(width: 10),
                      _miniCheck(eng, c.ppmComplete, 'PPM Report', 'Laporan PPM'),
                      const SizedBox(width: 10),
                      _miniCheck(eng, c.budgetComplete, 'Budget', 'Bajet'),
                      const SizedBox(width: 10),
                      _miniCheck(eng, c.resultComplete, 'Result', 'Keputusan'),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _deleteCase(c),
                        child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                            const SizedBox(height: 6),
                            Text(
                              eng ? 'Created: ${c.createdAt}' : 'Dicipta: ${c.createdAt}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D7377),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(eng ? 'New Case' : 'Kes Baru'),
        onPressed: _newCase,
      ),
    );
  }

  Widget _miniCheck(bool eng, bool done, String en, String bm) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: done ? Colors.green.shade600 : Colors.grey.shade400,
        ),
        const SizedBox(width: 3),
        Text(
          eng ? en : bm,
          style: TextStyle(fontSize: 10.5, color: done ? Colors.green.shade700 : Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Full editor for one repair case.
class RepairCaseEditorScreen extends StatefulWidget {
  final String caseId;
  const RepairCaseEditorScreen({super.key, required this.caseId});

  @override
  State<RepairCaseEditorScreen> createState() => _RepairCaseEditorScreenState();
}

class _RepairCaseEditorScreenState extends State<RepairCaseEditorScreen> {
  late RepairCase _c;
  late List<TextEditingController> _ctrls;
  final _picker = ImagePicker();
  List<Contractor> _contractors = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rebind();
    ContractorService.load().then((l) {
      if (mounted) setState(() => _contractors = l);
    });
  }

  void _rebind() {
    _c = RepairService.cases.firstWhere((x) => x.id == widget.caseId,
        orElse: () => RepairCase(id: widget.caseId, createdAt: RepairService.todayStr()));
    _ctrls = [
      TextEditingController(text: _c.building),
      TextEditingController(text: _c.system),
      TextEditingController(text: _c.problemType),
      TextEditingController(text: _c.description),
      TextEditingController(text: _c.priority),
      TextEditingController(text: _c.source),
      TextEditingController(text: _c.reportedBy),
      TextEditingController(text: _c.position),
      TextEditingController(text: _c.contractorName),
      TextEditingController(text: _c.contractorSystem),
      TextEditingController(text: _c.contractorPmDate),
      TextEditingController(text: _c.contractorPmResult),
      TextEditingController(text: _c.suggestion),
    ];
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    _c = _c.copy()
      ..building = _ctrls[0].text.trim()
      ..system = _ctrls[1].text.trim()
      ..problemType = _ctrls[2].text.trim()
      ..description = _ctrls[3].text.trim()
      ..priority = _ctrls[4].text.trim()
      ..source = _ctrls[5].text.trim()
      ..reportedBy = _ctrls[6].text.trim()
      ..position = _ctrls[7].text.trim()
      ..contractorName = _ctrls[8].text.trim()
      ..contractorSystem = _ctrls[9].text.trim()
      ..contractorPmDate = _ctrls[10].text.trim()
      ..contractorPmResult = _ctrls[11].text.trim()
      ..suggestion = _ctrls[12].text.trim();
    _c.contractorName = _c.contractorName.isNotEmpty
        ? _c.contractorName
        : (_contractors.isNotEmpty ? _contractors.first.name : '');
    _c.contractorSystem = _c.contractorSystem.isNotEmpty
        ? _c.contractorSystem
        : (_contractors.isNotEmpty ? _contractors.first.system : '');
  }

  void _persistLocal() {
    final idx = RepairService.cases.indexWhere((x) => x.id == _c.id);
    if (idx >= 0) {
      RepairService.cases[idx] = _c;
    }
  }

  Future<void> _saveAll() async {
    _sync();
    _persistLocal();
    final ok = await RepairService.persist();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Data saved'
            : (LanguageProvider.isEnglish(context) ? 'Save failed' : 'Simpan gagal')),
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save failed')));
    }
  }

  // ---------- DOCX GENERATION ----------

  Future<void> _generate(String kind) async {
    final eng = LanguageProvider.isEnglish(context);
    _sync();
    _persistLocal();
    setState(() => _saving = true);

    Uint8List? docx;
    try {
      switch (kind) {
        case 'incident':
          docx = await RepairDocxService.build(
            title: 'LAPORAN INSIDEN / ADUAN',
            titleEn: 'INCIDENT REPORT / COMPLAINT',
            refNo: _c.id,
            dateStr: _c.createdAt,
            fields: [
              RepairField('Sumber / Source', _c.source),
              RepairField('Dilapor oleh / Reported by', '${_c.reportedBy} (${_c.position})'),
              RepairField('Bangunan / Building', _c.building),
              RepairField('Sistem terlibat / System', _c.system),
              RepairField('Jenis masalah / Problem', _c.problemType),
              RepairField('Keutamaan / Priority', _c.priority),
              RepairField('Masa & tarikh / Date', _c.createdAt),
            ],
            paragraphs: [
              'PERIHALAN MASALAH / DESCRIPTION OF ISSUE:',
              _c.description.isEmpty ? '_______________________' : _c.description,
            ],
          );
          _c.incidentComplete = true;
        case 'ppm':
          docx = await RepairDocxService.build(
            title: 'LAPORAN PPM KONTRAKTOR',
            titleEn: 'CONTRACTOR PREVENTIVE MAINTENANCE REPORT',
            refNo: _c.id,
            dateStr: _c.contractorPmDate.isEmpty ? _c.createdAt : _c.contractorPmDate,
            fields: [
              RepairField('Kontraktor / Contractor', _c.contractorName),
              RepairField('Sistem / System', _c.contractorSystem),
              RepairField('Tarikh PM / PM date', _c.contractorPmDate),
              RepairField('Rujukan Kes / Case ref', _c.id),
            ],
            paragraphs: [
              'HASIL PEMERIKSAAN PM / PM INSPECTION RESULT:',
              _c.contractorPmResult.isEmpty ? '_______________________' : _c.contractorPmResult,
            ],
          );
          _c.ppmComplete = true;
        case 'budget':
          final rows = [
            for (final b in _c.budget)
              [b.item, '${b.qty}', b.unitPrice.toStringAsFixed(2), (b.qty * b.unitPrice).toStringAsFixed(2)],
            ['SUBTOTAL', '', '', _c.budgetTotal.toStringAsFixed(2)],
            ['CONTINGENCY 10%', '', '', _c.contingency.toStringAsFixed(2)],
            ['TOTAL (RM)', '', '', _c.grandTotal.toStringAsFixed(2)],
          ];
          docx = await RepairDocxService.build(
            title: 'CADANGAN & PERMOHONAN BAJET',
            titleEn: 'SUGGESTION & BUDGET REQUEST',
            refNo: _c.id,
            dateStr: _c.createdAt,
            fields: [
              RepairField('Kontraktor / Contractor', _c.contractorName),
              RepairField('Sistem terlibat / System', _c.system),
              RepairField('Bangunan / Building', _c.building),
            ],
            paragraphs: [
              'CADANGAN KAMI (BERDASARKAN CADANGAN KONTRAKTOR) / OUR SUGGESTION (BASED ON CONTRACTOR SUGGESTION):',
              _c.suggestion.isEmpty ? '_______________________' : _c.suggestion,
              'BAJET PEROLEHAN ITEM UNTUK MENYELESAIKAN MASALAH / BUDGET TO PURCHASE ITEMS TO SOLVE THE PROBLEM:',
            ],
            tableHeader: ['Item Description / Penerangan', 'Qty', 'Unit RM', 'Total RM'],
            tableRows: rows,
          );
          _c.budgetComplete = true;
        case 'permit':
          docx = await RepairDocxService.build(
            title: 'PERMOHONAN PERMIT KERJA',
            titleEn: 'WORK PERMIT REQUEST',
            refNo: _c.id,
            dateStr: _c.createdAt,
            fields: [
              RepairField('Kontraktor / Contractor', _c.contractorName),
              RepairField('Penerangan kerja / Work scope', '${_c.system} — ${_c.problemType}'),
              RepairField('Bangunan / Building', _c.building),
              RepairField('Keutamaan / Priority', _c.priority),
            ],
            paragraphs: [
              'Dengan ini pihak Cakra Mahkota Sdn Bhd memohon kontraktor menyediakan permit kerja '
              'sebelum memulakan kerja pembaikan rujukan ${_c.id}.',
            ],
          );
          _c.status = RepairStatus.permit;
          _c.permitRequestedAt = RepairService.todayStr();
        case 'result':
          final photos = <RepairPhoto>[
            for (var i = 0; i < _c.resultPhotos.length; i++)
              RepairPhoto(base64Decode(_c.resultPhotos[i]), 'Gambar ${i + 1} / Photo ${i + 1}'),
          ];
          docx = await RepairDocxService.build(
            title: 'LAPORAN KEPUTUSAN KERJA',
            titleEn: 'WORK RESULT REPORT',
            refNo: _c.id,
            dateStr: _c.completedAt.isEmpty ? _c.createdAt : _c.completedAt,
            fields: [
              RepairField('Sistem terlibat / System', _c.system),
              RepairField('Kontraktor / Contractor', _c.contractorName),
              RepairField('Bangunan / Building', _c.building),
            ],
            paragraphs: [
              'RINGKASAN KERJA / WORK SUMMARY:',
              ...(_c.resultNotes.isEmpty ? ['_______________________'] : _c.resultNotes),
              'GAMBAR KEPUTUSAN KERJA / WORK RESULT PHOTOS:',
            ],
            photos: photos,
          );
          _c.resultComplete = true;
          _c.status = RepairStatus.completed;
          _c.completedAt = RepairService.todayStr();
      }
    } catch (e) {
      debugPrint('[Repair] docx error: $e');
    }

    if (docx != null) {
      final path = await RepairService.saveDoc(_c.id, kind, docx);
      final saved = path != null;
      _persistLocal();
      await RepairService.persist();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved
              ? (eng ? 'Document generated & saved in database' : 'Dokumen dijana & disimpan dalam database')
              : (eng ? 'Document generated but saved locally only' : 'Dokumen dijana tetapi disimpan lokal sahaja')),
        ));
      }
    } else {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generation failed')));
      }
    }
  }

  Future<void> _submit() async {
    final eng = LanguageProvider.isEnglish(context);
    _sync();
    if (!_c.canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Complete incident report, PPM report and budget request first'
            : 'Lengkapkan dahulu laporan insiden, laporan PPM dan permohonan bajet'),
      ));
      return;
    }
    _c.status = RepairStatus.submitted;
    _c.submittedAt = RepairService.todayStr();
    _persistLocal();
    await RepairService.persist();
    if (mounted) setState(() {});
  }

  Future<void> _decide(bool approve) async {
    _c.status = approve ? RepairStatus.approved : RepairStatus.rejected;
    _c.decidedAt = RepairService.todayStr();
    _persistLocal();
    await RepairService.persist();
    if (mounted) setState(() {});
  }

  Future<void> _askPermitViaWhatsApp() async {
    final eng = LanguageProvider.isEnglish(context);
    Contractor? c;
    for (final e in _contractors) {
      if (e.name == _c.contractorName) {
        c = e;
        break;
      }
    }
    if (c == null || c.whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'No WhatsApp contact for ${_c.contractorName}'
            : 'Tiada nombor WhatsApp untuk ${_c.contractorName}'),
      ));
      return;
    }
    final phone = c.whatsapp.trim().replaceAll(RegExp(r'[^\d+]'), '');
    final msg = Uri.encodeComponent(RepairService.waTextForPermit(_c));
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not found')));
    }
  }

  Future<void> _execute() async {
    final eng = LanguageProvider.isEnglish(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Start repair execution?' : 'Mulakan pelaksanaan pembaikan?'),
        content: Text(eng
            ? 'Confirm with contractor that the work permit is ready, then mark the repair as in progress.'
            : 'Sahkan dengan kontraktor bahawa permit kerja sudah siap, kemudian tandakan pembaikan sebagai sedang berjalan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(eng ? 'Cancel' : 'Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(eng ? 'Execute' : 'Laksana')),
        ],
      ),
    );
    if (ok != true) return;
    _c.status = RepairStatus.executing;
    _c.executedAt = RepairService.todayStr();
    _persistLocal();
    await RepairService.persist();
    if (mounted) setState(() {});
  }

  Future<void> _pickResultPhoto() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _c = _c.copy()..resultPhotos = [..._c.resultPhotos, base64Encode(bytes)]);
    _persistLocal();
  }

  void _removeResultPhoto(int i) {
    final list = [..._c.resultPhotos]..removeAt(i);
    setState(() => _c = _c.copy()..resultPhotos = list);
    _persistLocal();
  }

  void _addBudgetItem() {
    setState(() => _c = _c.copy()..budget = [..._c.budget, BudgetItem()]);
    _persistLocal();
  }

  void _updateBudgetItem(int i, {String? item, int? qty, double? price}) {
    final b = _c.budget[i];
    final list = [..._c.budget];
    list[i] = BudgetItem(
      item: item ?? b.item,
      qty: qty ?? b.qty,
      unitPrice: price ?? b.unitPrice,
    );
    setState(() => _c = _c.copy()..budget = list);
    _persistLocal();
  }

  void _removeBudgetItem(int i) {
    final list = [..._c.budget]..removeAt(i);
    setState(() => _c = _c.copy()..budget = list);
    _persistLocal();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.caseId)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _statusFlow(eng),
              const SizedBox(height: 14),
              _section(
                eng,
                icon: Icons.report_problem_rounded,
                color: const Color(0xFFDC2626),
                title: eng ? '1. Incident Report / Complaint' : '1. Laporan Insiden / Aduan',
                subtitle: eng ? 'Complaint received by FM team' : 'Aduan diterima oleh pasukan FM',
                done: _c.incidentComplete,
                child: Column(
                  children: [
                    _row2([
                      _field(0, eng ? 'Building / Location' : 'Bangunan / Lokasi'),
                      _field(1, eng ? 'System Involved' : 'Sistem Terlibat'),
                    ]),
                    const SizedBox(height: 8),
                    _row2([
                      _field(2, eng ? 'Problem Type' : 'Jenis Masalah'),
                      _field(3, eng ? 'Priority' : 'Keutamaan'),
                    ]),
                    const SizedBox(height: 8),
                    _row2([
                      _field(4, eng ? 'Source (KKR/JKR/FMI)' : 'Sumber (KKR/JKR/FMI)'),
                      _field(5, eng ? 'Reported By' : 'Dilapor oleh'),
                    ]),
                    const SizedBox(height: 8),
                    _field(6, eng ? 'Position' : 'Jawatan'),
                    const SizedBox(height: 8),
                    _field(7, eng ? 'Description of Issue' : 'Penerangan Masalah', maxLines: 3),
                    const SizedBox(height: 10),
                    _genButton('incident', eng ? 'Generate Incident Report' : 'Jana Laporan Insiden'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                eng,
                icon: Icons.handyman_rounded,
                color: const Color(0xFF7C3AED),
                title: eng ? '2. Contractor PPM Report' : '2. Laporan PPM Kontraktor',
                subtitle: eng ? 'PM done by contractor for each scheduled PM' : 'PM dilakukan oleh kontraktor bagi setiap PM berjadual',
                done: _c.ppmComplete,
                child: Column(
                  children: [
                    _row2([
                      _dropdown(
                        eng ? 'Contractor' : 'Kontraktor',
                        _c.contractorName.isEmpty && _contractors.isNotEmpty ? _contractors.first.name : _c.contractorName,
                        _contractors.map((e) => e.name).toSet().toList(),
                        (v) {
                          Contractor? con;
                          for (final e in _contractors) {
                            if (e.name == v) con = e;
                          }
                          setState(() {
                            _c = _c.copy()
                              ..contractorName = v ?? _c.contractorName
                              ..contractorSystem = con?.system ?? _c.contractorSystem;
                            _ctrls[8].dispose();
                            _ctrls[9].dispose();
                            _ctrls[8] = TextEditingController(text: _c.contractorName);
                            _ctrls[9] = TextEditingController(text: _c.contractorSystem);
                          });
                          _persistLocal();
                        },
                      ),
                      _field(9, eng ? 'System' : 'Sistem'),
                    ]),
                    const SizedBox(height: 8),
                    _row2([
                      _field(10, eng ? 'PM Date' : 'Tarikh PM'),
                      _field(11, eng ? 'PM Result' : 'Hasil PM'),
                    ]),
                    const SizedBox(height: 10),
                    _genButton('ppm', eng ? 'Generate PPM Report' : 'Jana Laporan PPM'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                eng,
                icon: Icons.request_quote_rounded,
                color: const Color(0xFFF9A825),
                title: eng ? '3. Suggestion & Budget Request' : '3. Cadangan & Permohonan Bajet',
                subtitle: eng ? 'Our suggestion + budget to buy items, based on contractor suggestion' : 'Cadangan kami + bajet beli item, berdasarkan cadangan kontraktor',
                done: _c.budgetComplete,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field(12, eng ? 'Our Suggestion (based on contractor)' : 'Cadangan Kami (berasaskan kontraktor)', maxLines: 3),
                    const SizedBox(height: 10),
                    Text(
                      eng ? 'Budget Items to Purchase:' : 'Item Bajet untuk Dibeli:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (_c.budget.isEmpty)
                      Text(
                        eng ? 'No items yet — tap Add Item' : 'Tiada item lagi — tekan Tambah Item',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    for (var i = 0; i < _c.budget.length; i++) _budgetRow(i),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _addBudgetItem,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(eng ? 'Add Item' : 'Tambah Item'),
                        ),
                        const Spacer(),
                        Text(
                          'Total: RM ${_c.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0D7377)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _genButton('budget', eng ? 'Generate Budget Request' : 'Jana Permohonan Bajet'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _section(
                eng,
                icon: Icons.send_rounded,
                color: const Color(0xFF1565C0),
                title: eng ? '4. Submit All Documents' : '4. Hantar Semua Dokumen',
                subtitle: eng ? 'Submit incident, PPM and budget documents for approval' : 'Hantar dokumen insiden, PPM dan bajet untuk kelulusan',
                done: _c.status.index >= RepairStatus.submitted.index,
                child: Column(
                  children: [
                    _pillRow(eng),
                    const SizedBox(height: 10),
                    _actButton(
                      color: const Color(0xFF1565C0),
                      icon: Icons.send_rounded,
                      label: eng ? 'Submit All Documents' : 'Hantar Semua Dokumen',
                      onTap: _c.status == RepairStatus.draft ? _submit : null,
                    ),
                    if (_c.status == RepairStatus.submitted) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _actButton(
                              color: Colors.green,
                              icon: Icons.thumb_up_rounded,
                              label: eng ? 'Approve' : 'Lulus',
                              onTap: () => _decide(true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actButton(
                              color: Colors.red,
                              icon: Icons.thumb_down_rounded,
                              label: eng ? 'Reject' : 'Tolak',
                              onTap: () => _decide(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_c.status == RepairStatus.approved ||
                  _c.status == RepairStatus.rejected ||
                  _c.status == RepairStatus.permit ||
                  _c.status == RepairStatus.executing ||
                  _c.status == RepairStatus.completed) ...[
                const SizedBox(height: 12),
                _section(
                  eng,
                  icon: Icons.assignment_late_rounded,
                  color: const Color(0xFFE64A19),
                  title: eng ? '5. Work Permit & Execute Repair' : '5. Permit Kerja & Laksana Pembaikan',
                  subtitle: eng
                      ? 'After approval: contractor prepares work permit, then repair is executed'
                      : 'Selepas kelulusan: kontraktor sediakan permit kerja, kemudian pembaikan dilaksanakan',
                  done: _c.status == RepairStatus.permit || _c.status == RepairStatus.executing || _c.status == RepairStatus.completed,
                  child: Column(
                    children: [
                      if (_c.status == RepairStatus.approved) ...[
                        _actButton(
                          color: const Color(0xFF25D366),
                          icon: Icons.chat_rounded,
                          label: eng ? 'Ask Contractor for Work Permit (WhatsApp)' : 'Minta Kontraktor Sediakan Permit Kerja (WhatsApp)',
                          onTap: _askPermitViaWhatsApp,
                        ),
                        const SizedBox(height: 8),
                        _actButton(
                          color: const Color(0xFF0D7377),
                          icon: Icons.construction_rounded,
                          label: eng ? 'Execute Repair' : 'Laksana Pembaikan',
                          onTap: _execute,
                        ),
                      ],
                      if (_c.status == RepairStatus.rejected)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              eng ? 'Rejected on ${_c.decidedAt} — case archived.' : 'Ditolak pada ${_c.decidedAt} — kes diarkibkan.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                            ),
                          ),
                        ),
                      if (_c.status == RepairStatus.permit || _c.status == RepairStatus.executing)
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              eng
                                  ? 'Work permit requested on ${_c.permitRequestedAt} (${_c.contractorName}).'
                                  : 'Permit kerja diminta pada ${_c.permitRequestedAt} (${_c.contractorName}).',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  eng,
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF2E7D32),
                  title: eng ? '6. Work Result Report (with images)' : '6. Laporan Keputusan Kerja (dengan gambar)',
                  subtitle: eng ? 'Final report of completed work including photos' : 'Laporan akhir kerja siap termasuk gambar',
                  done: _c.resultComplete,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _c.resultNotes.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text('• ${_c.resultNotes[i]}', style: const TextStyle(fontSize: 13))),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  final list = [..._c.resultNotes]..removeAt(i);
                                  setState(() => _c = _c.copy()..resultNotes = list);
                                  _persistLocal();
                                },
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        initialValue: '',
                        decoration: InputDecoration(
                          labelText: eng ? 'Add result note' : 'Tambah nota keputusan',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onFieldSubmitted: (v) {
                          if (v.trim().isEmpty) return;
                          final list = [..._c.resultNotes, v.trim()];
                          setState(() => _c = _c.copy()..resultNotes = list);
                          _persistLocal();
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        eng ? 'Result Photos:' : 'Gambar Keputusan:',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _c.resultPhotos.length; i++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(_c.resultPhotos[i]),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => _removeResultPhoto(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          InkWell(
                            onTap: _pickResultPhoto,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _genButton('result', eng ? 'Generate Work Result Report' : 'Jana Laporan Keputusan Kerja'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(eng ? 'Save Case Data' : 'Simpan Data Kes'),
                ),
              ),
            ],
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: const Color(0x99051E24),
                child: const Center(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- shared widgets ----------

  Widget _statusFlow(bool eng) {
    final steps = [
      (RepairStatus.draft, 'Draft'),
      (RepairStatus.submitted, 'Submit'),
      (RepairStatus.approved, 'Approved'),
      (RepairStatus.permit, 'Permit'),
      (RepairStatus.executing, 'Execute'),
      (RepairStatus.completed, 'Done'),
    ];
    final cur = _c.status.index;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D7377).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eng ? 'Workflow Status' : 'Status Aliran Kerja',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0D7377)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 14,
                      height: 2,
                      color: i <= cur ? const Color(0xFF0D7377) : Colors.grey.shade300,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: i <= cur ? const Color(0xFF0D7377) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      steps[i].$2,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: i <= cur ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillRow(bool eng) {
    Widget pill(String label, bool filled) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: filled ? Colors.green.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.green.shade800 : Colors.grey.shade600,
            ),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pill(eng ? 'Incident' : 'Insiden', _c.incidentComplete),
        const SizedBox(width: 6),
        pill(eng ? 'PPM' : 'PPM', _c.ppmComplete),
        const SizedBox(width: 6),
        pill(eng ? 'Budget' : 'Bajet', _c.budgetComplete),
        const SizedBox(width: 6),
        pill(eng ? 'Submitted' : 'Dihantar', _c.status.index >= RepairStatus.submitted.index),
      ],
    );
  }

  Widget _section(bool eng, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool done,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3)),
                  ],
                ),
              ),
              if (done)
                Icon(Icons.check_circle_rounded, size: 18, color: Colors.green.shade600)
              else
                Icon(Icons.radio_button_unchecked_rounded, size: 18, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _row2(List<Widget> children) => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      );

  Widget _field(int idx, String label, {int maxLines = 1}) => TextField(
        controller: _ctrls[idx],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        style: const TextStyle(fontSize: 13),
      );

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    if (items.isEmpty) {
      return _field(0, label);
    }
    final safeValue = items.contains(value) ? value : (items.first);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _budgetRow(int i) {
    final b = _c.budget[i];
    return KeyedSubtree(
      key: ValueKey('budget-row-$i'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: b.item,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Item',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => _updateBudgetItem(i, item: v),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 54,
              child: TextFormField(
                initialValue: '${b.qty}',
                style: const TextStyle(fontSize: 12.5),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Qty',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => _updateBudgetItem(i, qty: int.tryParse(v) ?? 1),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 76,
              child: TextFormField(
                initialValue: b.unitPrice.toStringAsFixed(2),
                style: const TextStyle(fontSize: 12.5),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'RM',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) => _updateBudgetItem(i, price: double.tryParse(v) ?? 0),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              onPressed: () => _removeBudgetItem(i),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genButton(String kind, String label) {
    final colors = {
      'incident': const Color(0xFFDC2626),
      'ppm': const Color(0xFF7C3AED),
      'budget': const Color(0xFFF9A825),
      'permit': const Color(0xFFE64A19),
      'result': const Color(0xFF2E7D32),
    };
    final color = colors[kind]!;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
        label: Text(label),
        onPressed: _saving ? null : () => _generate(kind),
      ),
    );
  }

  Widget _actButton({
    required Color color,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        onPressed: onTap,
      ),
    );
  }
}