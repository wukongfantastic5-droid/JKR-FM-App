import 'dart:convert';

import 'package:flutter/material.dart';
import '../data/technician_data.dart';
import '../data/contractor_data.dart';
import '../localization.dart';
import '../services/repo_service.dart';
import '../services/tech_service.dart';
import '../services/contractor_service.dart';
import '../services/complaint_service.dart';
import '../services/doc_deliver.dart';
import '../services/repair_docx.dart';
import '../services/session_service.dart';
import 'admin_tech_screen.dart';
import 'contractor_list_screen.dart';
import 'tech_account_screen.dart';

/// Admin "User Account" hub: lists every technician, contractor and
/// complainer account. Tapping an account logs straight into that account's
/// full dashboard (for launch testing); edit/manage stays one tap away.
class UserAccountScreen extends StatefulWidget {
  const UserAccountScreen({super.key});

  @override
  State<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends State<UserAccountScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  Future<void> _downloadDocs() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() => _downloading = true);
    try {
      await TechService.loadTechStatus();
      await ContractorService.load();
      final tickets = await ComplaintService.load();
      final complainers = <String, ({String name, String phone, String floor})>{};
      for (final t in tickets) {
        if (t.userId.isEmpty) continue;
        final existing = complainers[t.userId];
        if (existing == null) {
          complainers[t.userId] = (
            name: t.complainerName,
            phone: t.complainerPhone ?? '',
            floor: t.floor,
          );
        } else {
          complainers[t.userId] = (
            name: existing.name,
            phone: existing.phone,
            floor: existing.floor.isEmpty ? t.floor : existing.floor,
          );
        }
      }

      final rows = <List<String>>[];
      var no = 1;
      for (final t in TechService.technicians) {
        rows.add([
          '$no',
          'Teknisi',
          t.name,
          t.email.isNotEmpty ? t.email : 'ID ${t.id}',
          t.password,
          t.phone,
        ]);
        no++;
      }
      for (final c in ContractorService.entries) {
        rows.add([
          '$no',
          'Kontraktor',
          c.name,
          c.email,
          c.password,
          c.contact.isNotEmpty ? c.contact : c.whatsapp,
        ]);
        no++;
      }
      for (final e in complainers.entries) {
        rows.add([
          '$no',
          'Pengadu',
          e.value.name,
          e.value.name,
          '-',
          e.value.phone,
        ]);
        no++;
      }
      if (rows.isEmpty) {
        rows.add(['1', '-', '-', '-', '-', '-']);
      }

      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-${now.year}';
      final ref = 'ACC-${now.day.toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';
      final fileStr = 'User_Accounts_${now.year}'
          '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final docx = await RepairDocxService.build(
        title: 'SENARAI AKAUN PENGGUNA',
        titleEn: 'USER ACCOUNT LIST',
        refNo: ref,
        dateStr: dateStr,
        paragraphs: const [
          'JADUAL 1: SENARAI AKAUN PENGGUNA (KATA LALUAN) / TABLE 1: USER ACCOUNT LIST (PASSWORDS)',
        ],
        tableHeader: ['No', 'Jenis', 'Nama', 'Login', 'Kata Laluan', 'No. Telefon'],
        colWidthsCm: const [1.1, 2.4, 4.6, 4.4, 2.3, 3.4],
        tableRows: rows,
      );

      final savedLocalPath = await DocDeliver.saveLocal(
          'User Account', '$fileStr.docx', docx);
      final savedLocal = savedLocalPath.isNotEmpty;
      final localPath = savedLocalPath;
      final savedRepo = await RepoService.writeRawFile(
        'Reports/User_Account/$fileStr.docx',
        base64Encode(docx),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(savedRepo
              ? (savedLocal
                  ? (eng
                      ? 'Saved: $localPath\\$fileStr.docx'
                      : 'Disimpan: $localPath\\$fileStr.docx')
                  : (eng
                      ? 'Saved in database (Reports/User_Account)'
                      : 'Disimpan dalam database (Reports/User_Account)'))
              : (eng ? 'Generate ok but save failed' : 'Jana berjaya tetapi simpan gagal')),
        ));
        if (savedRepo) {
          await DocDeliver.offerOpen(
            context,
            repoPath: 'Reports/User_Account/$fileStr.docx',
            eng: eng,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Download failed: $e' : 'Muat turun gagal: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'User Account' : 'Akaun Pengguna'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: eng
                  ? 'Download account list (Word)'
                  : 'Muat turun senarai akaun (Word)',
              onPressed: _downloading ? null : _downloadDocs,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.engineering_rounded, size: 20),
              text: eng ? 'Technician' : 'Teknisi',
            ),
            Tab(
              icon: const Icon(Icons.handshake_rounded, size: 20),
              text: eng ? 'Contractor' : 'Kontraktor',
            ),
            Tab(
              icon: const Icon(Icons.report_problem_rounded, size: 20),
              text: eng ? 'Complainer' : 'Pengadu',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TechnicianTab(onManage: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminTechScreen()),
            );
          }),
          _ContractorTab(onManage: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContractorListScreen()),
            );
          }),
          const _ComplainerTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TechnicianTab extends StatefulWidget {
  final VoidCallback onManage;
  const _TechnicianTab({required this.onManage});

  @override
  State<_TechnicianTab> createState() => _TechnicianTabState();
}

class _TechnicianTabState extends State<_TechnicianTab> {
  List<Technician>? _techs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _techs = null;
      _error = null;
    });
    try {
      await RepoService.ensureEnv();
      await TechService.loadTechStatus();
      if (!mounted) return;
      setState(() => _techs = TechService.technicians);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    final techs = _techs;
    if (techs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: techs.length + 1,
        itemBuilder: (c, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                eng
                    ? 'Tap an account to log in as that technician instantly.'
                    : 'Ketuk akaun untuk log masuk sebagai teknisi tersebut serta-merta.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            );
          }
          final t = techs[i - 1];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0D7377),
              backgroundImage:
                  t.photoPath.isNotEmpty ? NetworkImage(TechService.photoUrl(t)) : null,
              child: t.photoPath.isNotEmpty
                  ? null
                  : Text(t.id,
                      style:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            title: Text(t.name),
            subtitle: Text(t.email.isNotEmpty ? t.email : 'ID ${t.id}'),
            trailing: IconButton(
              tooltip: eng ? 'Edit account' : 'Edit akaun',
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute(builder: (_) => TechAccountScreen(existing: t)),
              ),
            ),
            onTap: () => SessionService.loginAsTech(c, t.id, t.name, role: t.role),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ContractorTab extends StatefulWidget {
  final VoidCallback onManage;
  const _ContractorTab({required this.onManage});

  @override
  State<_ContractorTab> createState() => _ContractorTabState();
}

class _ContractorTabState extends State<_ContractorTab> {
  List<Contractor>? _entries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = null;
    });
    try {
      await RepoService.ensureEnv();
      final list = await ContractorService.load();
      if (!mounted) return;
      setState(() => _entries = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    final list = _entries;
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Text(eng ? 'No contractor accounts yet' : 'Tiada akaun kontraktor lagi'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: list.length + 1,
        itemBuilder: (c, i) {
          if (i == 0) {
            return ListTile(
              title: Text(eng ? 'Login as contractor' : 'Log masuk sebagai kontraktor'),
              subtitle: Text('Password: 123456 — '
                  '${eng ? 'tap account to use it' : 'ketuk akaun untuk guna'}'),
              trailing: IconButton(
                tooltip: eng ? 'Manage contractors' : 'Urus kontraktor',
                icon: const Icon(Icons.settings_rounded, size: 20),
                onPressed: widget.onManage,
              ),
            );
          }
          final k = list[i - 1];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF7C3AED),
              child: Text(
                k.name.isNotEmpty ? k.name[0] : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(k.name),
            subtitle: Text('${k.system}${k.contact.isNotEmpty ? ' • ${k.contact}' : ''}'),
            trailing: IconButton(
              tooltip: eng ? 'Edit account' : 'Edit akaun',
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => widget.onManage(),
            ),
            onTap: () => SessionService.loginAsContractor(c, k),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ComplainerTab extends StatefulWidget {
  const _ComplainerTab();

  @override
  State<_ComplainerTab> createState() => _ComplainerTabState();
}

class _ComplainerTabState extends State<_ComplainerTab> {
  List<_Complainer>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _users = null;
      _error = null;
    });
    try {
      final tickets = await ComplaintService.load();
      final map = <String, _Complainer>{};
      for (final t in tickets) {
        final uid = t.userId;
        if (uid.isEmpty) continue;
        final existing = map[uid];
        if (existing == null) {
          map[uid] = _Complainer(
            uid: uid,
            name: t.complainerName,
            phone: t.complainerPhone ?? '',
            floor: t.floor,
            count: 1,
          );
        } else {
          existing.count++;
          existing.floor = existing.floor.isEmpty ? t.floor : existing.floor;
        }
      }
      final list = map.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() => _users = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    final list = _users;
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Text(eng ? 'No complainer accounts yet' : 'Tiada akaun pengadu lagi'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: list.length + 1,
        itemBuilder: (c, i) {
          if (i == 0) {
            return ListTile(
              title: Text(eng ? 'Login as a complainer' : 'Log masuk sebagai pengadu'),
              subtitle: Text(eng
                  ? 'Accounts are taken from submitted complaints'
                  : 'Akaun diambil daripada aduan yang dihantar'),
            );
          }
          final u = list[i - 1];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFDC2626),
              child: Text(
                u.name.isNotEmpty ? u.name[0] : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(u.name),
            subtitle: Text(
              [if (u.phone.isNotEmpty) u.phone, if (u.floor.isNotEmpty) u.floor, '$u.count complaints']
                  .join(' • '),
            ),
            onTap: () => SessionService.loginAsComplainer(
              c,
              uid: u.uid,
              name: u.name,
              level: u.floor,
            ),
          );
        },
      ),
    );
  }
}

class _Complainer {
  final String uid;
  final String name;
  String phone;
  String floor;
  int count;
  _Complainer({
    required this.uid,
    required this.name,
    required this.phone,
    required this.floor,
    required this.count,
  });
}