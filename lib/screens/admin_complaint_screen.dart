import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../data/complaint_data.dart';
import '../services/auth_service.dart';
import '../services/complaint_service.dart';
import '../widgets/http_error_banner.dart';
import '../services/form_ocr_service.dart';
import '../widgets/form_scan_sheet.dart';
import '../widgets/pin_asset_sheet.dart';
import '../services/doc_deliver.dart';
import '../services/excel_service.dart';
import '../services/repo_service.dart';

class AdminComplaintScreen extends StatefulWidget {
  const AdminComplaintScreen({super.key});

  @override
  State<AdminComplaintScreen> createState() => _AdminComplaintScreenState();
}

class _AdminComplaintScreenState extends State<AdminComplaintScreen> {
  List<ComplaintTicket> _tickets = [];
  bool _loading = true;
  bool _scanning = false;
  bool _exporting = false;
  String _filter = 'all';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh so updates made from other screens (pin sheet, building
    // view, another device) appear without pulling to refresh.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final tickets = await ComplaintService.load();
    tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _tickets = tickets;
  }

  Future<void> _silentRefresh() async {
    try {
      await _fetch();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  List<ComplaintTicket> get _filtered {
    if (_filter == 'all') return _tickets;
    return _tickets.where((t) => t.status == _filter).toList();
  }

  int _count(String s) => _tickets.where((t) => t.status == s).length;

  Future<void> _exportExcel(bool eng) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final now = DateTime.now();
      final fileDate = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final bytes = await ExcelService.build([
        ExcelSheet(
          name: 'Complaints',
          headers: const [
            'No', 'No. Ruj', 'Nama Pengadu', 'Telefon', 'Aras',
            'Jenis Kerja', 'Katagori', 'Keutamaan', 'Aset', 'Status',
            'Tarikh Lapor', 'Dicipta',
          ],
          rows: [
            for (final t in _tickets)
              [
                '${t.seqId}',
                t.noRuj ?? '',
                t.complainerName,
                t.complainerPhone ?? '',
                t.floor,
                t.issueType,
                t.workCategory ?? '',
                t.priority ?? '',
                t.assetName ?? '',
                t.status,
                t.reportedAt ?? '',
                '${t.createdAt.day.toString().padLeft(2, '0')}-'
                    '${t.createdAt.month.toString().padLeft(2, '0')}-'
                    '${t.createdAt.year}',
              ],
          ],
        ),
      ]);
      final fileName = 'Complaints_$fileDate.xlsx';
      final local = await DocDeliver.saveLocal('Complaints', fileName, bytes);
      final ok = await RepoService.writeRawFile(
          'Reports/Complaints/$fileName', base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (local.isNotEmpty
                ? (eng ? 'Saved: $local' : 'Disimpan: $local')
                : (eng
                    ? 'Saved in database (Reports/Complaints)'
                    : 'Disimpan dalam database (Reports/Complaints)'))
            : (eng ? 'Export ok but save failed' : 'Eksport berjaya tetapi simpan gagal')),
      ));
      if (ok) {
        await DocDeliver.offerOpen(
          context,
          repoPath: 'Reports/Complaints/$fileName',
          eng: eng,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Export failed: $e' : 'Eksport gagal: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Complaint Management' : 'Pengurusan Aduan'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.table_chart_rounded),
              tooltip: eng ? 'Export to Excel' : 'Eksport ke Excel',
              onPressed: _exporting ? null : () => _exportExcel(eng),
            ),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: Column(
              children: [
                const HttpErrorBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : () => _scanAndCreate(eng),
                      icon: _scanning
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.document_scanner_rounded),
                      label: Text(eng ? 'Scan Complaint Form' : 'Imbas Borang Aduan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7377),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                _buildFilterBar(eng),
                Expanded(child: _filtered.isEmpty
                  ? Center(child: Text(eng ? 'No complaints' : 'Tiada aduan',
                      style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildTicketCard(_filtered[i], eng),
                    ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _scanAndCreate(bool eng) async {
    setState(() => _scanning = true);
    try {
      final outcome = await pickAndScanForm(context, eng: eng);
      if (outcome == null || !mounted) return;
      final result = outcome.result;
      if (result.filledCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eng ? 'No form fields recognised. Try a clearer photo.' : 'Tiada medan borang dikenali. Cuba gambar yang lebih jelas.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }
      final confirmed = await _showScanConfirm(result, eng);
      if (confirmed != true) return;
      await _createTicket(result, outcome.evidenceBase64, eng);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eng ? 'Scan failed: $e' : 'Imbasan gagal: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<bool?> _showScanConfirm(FormOcrResult r, bool eng) {
    final rows = <(String, String)>[
      ('Nama Pengadu', r.complainerName),
      ('No. Telefon', r.phone),
      ('Tarikh & Masa', r.dateTime),
      (eng ? 'Aras (Floor)' : 'Aras', r.floor),
      ('Jenis Kerja', r.issueType),
      ('Katagori Kerja', r.workCategory),
      ('Keutamaan', r.priority),
      ('No. Ruj', r.noRuj),
      ('Aset', r.asset),
      (eng ? 'Keterangan' : 'Keterangan', r.description),
    ].where((e) => e.$2.isNotEmpty).toList();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Form Scanned' : 'Borang Diimbas'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eng
                  ? '${rows.length} field(s) found. Create complaint ticket?'
                  : '${rows.length} medan ditemui. Cipta tiket aduan?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              _showRawOcr(r, eng);
            },
            child: Text(eng ? 'Raw OCR' : 'OCR Mentah'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(eng ? 'Cancel' : 'Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Create Ticket' : 'Cipta Tiket'),
          ),
        ],
      ),
    );
  }

  void _showRawOcr(FormOcrResult r, bool eng) {
    final text = r.rawLines.isEmpty
        ? (eng ? '(no text detected)' : '(tiada teks dikesan)')
        : r.rawLines.join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Raw OCR Text' : 'Teks OCR Mentah'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(text, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(eng ? 'OK' : 'OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTicket(FormOcrResult result, String evidenceBase64, bool eng) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService.currentUser?.uid ?? 'admin';
    final userName = prefs.getString('user_name_$uid') ?? (eng ? 'Admin' : 'Admin');

    final ticket = ComplaintTicket(
      userId: uid,
      complainerName: result.complainerName.isNotEmpty ? result.complainerName : userName,
      complainerPhone: result.phone.isNotEmpty ? result.phone : null,
      reportedAt: result.dateTime.isNotEmpty ? result.dateTime : null,
      floor: result.floor.isNotEmpty ? result.floor : '1',
      issueType: result.issueType.isNotEmpty ? result.issueType : (eng ? 'OTHER' : 'LAIN'),
      workCategory: result.workCategory.isNotEmpty ? result.workCategory : null,
      priority: result.priority.isNotEmpty ? result.priority : null,
      noRuj: result.noRuj.isNotEmpty ? result.noRuj : null,
      assetName: result.asset.isNotEmpty ? result.asset : null,
      description: result.description.isNotEmpty ? result.description : (eng ? 'No description' : 'Tiada penerangan'),
    );

    final ok = await ComplaintService.add(ticket, evidenceBase64: evidenceBase64);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eng ? 'Complaint ticket #${ticket.seqId} created.' : 'Tiket aduan #${ticket.seqId} dicipta.'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eng ? 'Failed to create ticket. Check network.' : 'Gagal cipta tiket. Periksa rangkaian.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildFilterBar(bool eng) {
    final chips = <String>['all', 'open', 'in_progress', 'resolved'];
    final labels = {
      'all': eng ? 'All' : 'Semua',
      'open': eng ? 'Open' : 'Baru',
      'in_progress': eng ? 'In Progress' : 'Dalam Kerja',
      'resolved': eng ? 'Resolved' : 'Selesai',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((c) {
            final active = _filter == c;
            final count = c == 'all' ? _tickets.length : _count(c);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${labels[c]} ($count)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : null)),
                selected: active,
                onSelected: (_) => setState(() => _filter = c),
                selectedColor: _chipColor(c),
                checkmarkColor: Colors.white,
                backgroundColor: Colors.grey.shade100,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _chipColor(String s) {
    switch (s) {
      case 'open': return const Color(0xFFEF4444);
      case 'in_progress': return const Color(0xFFF59E0B);
      case 'resolved': return const Color(0xFF22C55E);
      default: return const Color(0xFF0D7377);
    }
  }

  Widget _buildTicketCard(ComplaintTicket t, bool eng) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(t, eng),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _statusColor(t.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon(t.status), color: _statusColor(t.status), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(t.noRuj != null ? '${t.noRuj} — Aras ${t.floor}' : '#${t.seqId} ${t.issueType.toUpperCase()} — Aras ${t.floor}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D7377).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(t.complainerName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D7377)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(t.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _statusBadge(t.status, eng),
                        const Spacer(),
                        Text(_formatDate(t.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _statusColor(String s) {
    switch (s) {
      case 'open': return const Color(0xFFEF4444);
      case 'in_progress': return const Color(0xFFF59E0B);
      case 'resolved': return const Color(0xFF22C55E);
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'open': return Icons.new_releases_rounded;
      case 'in_progress': return Icons.engineering_rounded;
      case 'resolved': return Icons.check_circle_rounded;
      default: return Icons.help_rounded;
    }
  }

  Widget _statusBadge(String status, bool eng) {
    final label = status == 'open' ? (eng ? 'Open' : 'Baru')
        : status == 'in_progress' ? (eng ? 'In Progress' : 'Dalam Kerja')
        : (eng ? 'Resolved' : 'Selesai');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status))),
    );
  }

  Future<void> _openDetail(ComplaintTicket t, bool eng) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _AdminComplaintDetail(ticket: t)),
    );
    if (result == true) _load();
  }
}

class _AdminComplaintDetail extends StatefulWidget {
  final ComplaintTicket ticket;
  const _AdminComplaintDetail({required this.ticket});

  @override
  State<_AdminComplaintDetail> createState() => _AdminComplaintDetailState();
}

class _AdminComplaintDetailState extends State<_AdminComplaintDetail> {
  late String _status;
  final _descCtrl = TextEditingController();
  String? _evidenceB64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
    _descCtrl.text = widget.ticket.description;
    _loadEvidence();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvidence() async {
    if (widget.ticket.evidenceFile == null) return;
    final b64 = await ComplaintService.getEvidenceBase64(widget.ticket.evidenceFile!);
    if (mounted) setState(() => _evidenceB64 = b64);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ComplaintService.update(
      widget.ticket.id,
      status: _status,
      description: _descCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Updated' : 'Failed to save — check network'),
          backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Complaint'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await ComplaintService.delete(widget.ticket.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Deleted' : 'Failed to delete — check network'),
          backgroundColor: ok ? const Color(0xFFEF4444) : Colors.orange.shade800,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final t = widget.ticket;
    return Scaffold(
      appBar: AppBar(title: Text('#${t.seqId} ${t.issueType.toUpperCase()} — Aras ${t.floor}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Text(eng ? 'Status:' : 'Status:', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _status,
                items: ['open', 'in_progress', 'resolved'].map((s) {
                  final label = s == 'open' ? (eng ? 'Open' : 'Baru')
                      : s == 'in_progress' ? (eng ? 'In Progress' : 'Dalam Kerja')
                      : (eng ? 'Resolved' : 'Selesai');
                  return DropdownMenuItem(value: s, child: Text(label));
                }).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('#${t.seqId} ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0D7377))),
            Text('${eng ? 'Complainer' : 'Pengadu'}: ${t.complainerName}', style: const TextStyle(fontSize: 13)),
          ]),
          if (t.noRuj != null) ...[
            const SizedBox(height: 4),
            Text('No. Ruj: ${t.noRuj}', style: const TextStyle(fontSize: 13)),
          ],
          if (t.complainerPhone != null) ...[
            const SizedBox(height: 4),
            Text('No. Telefon: ${t.complainerPhone}', style: const TextStyle(fontSize: 13)),
          ],
          if (t.reportedAt != null) ...[
            const SizedBox(height: 4),
            Text('${eng ? 'Reported' : 'Dilaporkan'}: ${t.reportedAt}', style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 4),
          Text('${eng ? 'Floor' : 'Aras'}: ${t.floor}', style: const TextStyle(fontSize: 13)),
          if (t.issueType.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${eng ? 'Work Type (Jenis Kerja)' : 'Jenis Kerja'}: ${t.issueType}', style: const TextStyle(fontSize: 13)),
          ],
          if ((t.assignedAsset ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFF0D7377)),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${eng ? "Assigned to" : "Disemat ke"}: ${t.assignedAsset}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D7377))),
              ),
            ]),
          ],
          if (t.workCategory != null) ...[
            const SizedBox(height: 4),
            Text('${eng ? 'Category (Katagori Kerja)' : 'Katagori Kerja'}: ${t.workCategory}', style: const TextStyle(fontSize: 13)),
          ],
          if (t.priority != null) ...[
            const SizedBox(height: 4),
            Text('${eng ? 'Priority (Keutamaan)' : 'Keutamaan'}: ${t.priority}', style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 4),
          Text('${eng ? 'Date' : 'Tarikh'}: ${_formatDate(t.createdAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (t.updatedAt != null)
            Text('${eng ? 'Last updated' : 'Kemaskini'}: ${_formatDate(t.updatedAt!)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: eng ? 'Description' : 'Penerangan',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          if (_evidenceB64 != null) ...[
            Text(eng ? 'Evidence:' : 'Bukti:', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                  body: Center(
                    child: InteractiveViewer(child: Image.memory(base64Decode(_evidenceB64!))),
                  ),
                ),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(base64Decode(_evidenceB64!), height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ] else if (t.evidenceFile != null)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => showPinAssetSheet(context, t, eng),
            icon: Icon(Icons.push_pin_rounded,
              color: (t.assignedAsset ?? '').isNotEmpty ? const Color(0xFF0D7377) : Colors.grey.shade600),
            label: Text((t.assignedAsset ?? '').isNotEmpty
                ? (eng ? 'Change Asset Pin' : 'Ubah Sematan Aset')
                : (eng ? 'Pin to Asset' : 'Semat ke Aset')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D7377),
              side: const BorderSide(color: Color(0xFF0D7377)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              minimumSize: const Size.fromHeight(0),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                  label: Text(eng ? 'Save Changes' : 'Simpan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7377),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_rounded),
                  label: Text(eng ? 'Delete' : 'Padam'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
