import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../data/complaint_data.dart';
import '../services/complaint_service.dart';
import '../widgets/pin_asset_sheet.dart';
import 'new_complaint_screen.dart';

class _EvidenceThumbnail extends StatefulWidget {
  final String evidenceFile;
  final Map<String, String> evidenceCache;
  final ValueChanged<String> onLoaded;
  final ValueChanged<String?> onTap;

  const _EvidenceThumbnail({
    required this.evidenceFile,
    required this.evidenceCache,
    required this.onLoaded,
    required this.onTap,
  });

  @override
  State<_EvidenceThumbnail> createState() => _EvidenceThumbnailState();
}

class _EvidenceThumbnailState extends State<_EvidenceThumbnail> {
  String? _b64;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.evidenceCache.containsKey(widget.evidenceFile)) {
      setState(() => _b64 = widget.evidenceCache[widget.evidenceFile]);
      return;
    }
    final b64 = await ComplaintService.getEvidenceBase64(widget.evidenceFile);
    if (mounted && b64 != null) {
      setState(() => _b64 = b64);
      widget.onLoaded(b64);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_b64 == null) {
      return Container(
        height: 60, width: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return GestureDetector(
      onTap: () => widget.onTap(_b64),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(base64Decode(_b64!), height: 60, width: 80, fit: BoxFit.cover),
      ),
    );
  }
}

class ComplaintDashboardScreen extends StatefulWidget {
  const ComplaintDashboardScreen({super.key});

  @override
  State<ComplaintDashboardScreen> createState() => _ComplaintDashboardScreenState();
}

class _ComplaintDashboardScreenState extends State<ComplaintDashboardScreen> {
  List<ComplaintTicket> _tickets = [];
  bool _loading = true;
  final Map<String, String> _evidenceCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('complainer_uid') ?? '';
    if (userId.isNotEmpty) {
      _tickets = await ComplaintService.getByUser(userId);
    }
    if (mounted) setState(() => _loading = false);
  }

  int _count(String status) => _tickets.where((t) => t.status == status).length;

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'My Complaints' : 'Aduan Saya')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _tickets.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(eng ? 'No complaints yet' : 'Tiada aduan lagi',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _newComplaint(eng),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(eng ? 'File a Complaint' : 'Buat Aduan'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  _buildSummary(eng),
                  Expanded(child: _buildList(eng)),
                ],
              ),
            ),
      floatingActionButton: _tickets.isEmpty ? null : FloatingActionButton.extended(
        onPressed: () => _newComplaint(eng),
        icon: const Icon(Icons.add_rounded),
        label: Text(eng ? 'New Complaint' : 'Aduan Baru'),
      ),
    );
  }

  Widget _buildSummary(bool eng) {
    final open = _count('open');
    final prog = _count('in_progress');
    final done = _count('resolved');
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _SummaryCard(
            icon: Icons.new_releases_rounded,
            value: '$open',
            label: eng ? 'Open' : 'Baru',
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            icon: Icons.engineering_rounded,
            value: '$prog',
            label: eng ? 'In Progress' : 'Dalam Kerja',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            icon: Icons.check_circle_rounded,
            value: '$done',
            label: eng ? 'Resolved' : 'Selesai',
            color: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool eng) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _tickets.length,
      itemBuilder: (_, i) {
        final t = _tickets[i];
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
                        Text('#${t.seqId} ${t.issueType.toUpperCase()} — Aras ${t.floor}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(t.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (t.evidenceFile != null) ...[
                          const SizedBox(height: 6),
                          _EvidenceThumbnail(
                            evidenceFile: t.evidenceFile!,
                            evidenceCache: _evidenceCache,
                            onLoaded: (b64) {
                              if (mounted) setState(() => _evidenceCache[t.evidenceFile!] = b64);
                            },
                            onTap: (b64) => _showEvidence(b64),
                          ),
                        ],
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
      },
    );
  }

  Future<void> _openDetail(ComplaintTicket t, bool eng) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ComplainerTicketSheet(ticket: t, eng: eng),
    );
    if (changed == true) _load();
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

  void _showEvidence(String? b64) {
    if (b64 == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: InteractiveViewer(
            child: Image.memory(base64Decode(b64)),
          ),
        ),
      ),
    ));
  }

  void _newComplaint(bool eng) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewComplaintScreen()),
    );
    if (result == true) _load();
  }
}

class _ComplainerTicketSheet extends StatefulWidget {
  final ComplaintTicket ticket;
  final bool eng;

  const _ComplainerTicketSheet({required this.ticket, required this.eng});

  @override
  State<_ComplainerTicketSheet> createState() => _ComplainerTicketSheetState();
}

class _ComplainerTicketSheetState extends State<_ComplainerTicketSheet> {
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.ticket.description);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  /// Lets the admin manually pin this ticket to the real affected asset on
  /// the ticket's floor (e.g. OTHER MECHANICAL → BLIND SPOT MIRROR 1).
  Future<void> _pinToAsset(bool eng) =>
      showPinAssetSheet(context, widget.ticket, eng);

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ComplaintService.update(
      widget.ticket.id,
      description: _descCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Updated' : 'Failed to save — check network'),
        backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      ),
    );
    Navigator.of(context).pop(ok);
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Deleted' : 'Failed to delete — check network'),
        backgroundColor: ok ? const Color(0xFFEF4444) : Colors.orange.shade800,
      ),
    );
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final eng = widget.eng;
    final t = widget.ticket;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 4, bottom: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            Text('#${t.seqId} ${t.issueType.toUpperCase()} — Aras ${t.floor}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            if (t.noRuj != null) ...[
              const SizedBox(height: 4),
              Text('No. Ruj: ${t.noRuj}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 4),
            Text('${eng ? 'Status' : 'Status'}: ${t.status == 'open' ? (eng ? 'Open' : 'Baru') : t.status == 'in_progress' ? (eng ? 'In Progress' : 'Dalam Kerja') : (eng ? 'Resolved' : 'Selesai')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if ((t.assignedAsset ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFF0D7377)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${eng ? "Assigned to" : "Disemat ke"}: ${t.assignedAsset}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D7377))),
                ),
              ]),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: eng ? 'Description' : 'Penerangan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _pinToAsset(eng),
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
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}
