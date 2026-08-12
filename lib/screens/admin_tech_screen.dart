import 'package:flutter/material.dart';
import '../localization.dart';
import '../providers/theme_provider.dart';
import '../services/repo_service.dart';
import '../services/tech_service.dart';
import '../data/technician_data.dart';
import 'tech_account_screen.dart';
import 'tech_dashboard.dart';

class AdminTechScreen extends StatefulWidget {
  const AdminTechScreen({super.key});

  @override
  State<AdminTechScreen> createState() => _AdminTechScreenState();
}

class _AdminTechScreenState extends State<AdminTechScreen> {
  List<PpmItem> _ppmItems = [];
  List<Technician> _techs = [];
  bool _loading = true;
  String? _selectedSystem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await TechService.loadTechStatus();
    _ppmItems = await TechService.loadPpmData();
    if (_ppmItems.isEmpty) {
      await repoServiceRefresh();
      _ppmItems = await TechService.loadPpmData();
    }
    if (mounted) {
      setState(() {
        _techs = TechService.technicians;
        _loading = false;
      });
    }
  }

  Future<void> repoServiceRefresh() async => RepoService.refresh();

  Future<void> _openAccountScreen({Technician? tech}) async {
    await TechService.loadTechStatus();
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TechAccountScreen(existing: tech)),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = ThemeProvider.isDark(context);
    final bg = isDark ? const Color(0xFF111318) : const Color(0xFFF8F9FA);

    return Scaffold(
      appBar: AppBar(
        title: Text(eng ? 'Technician Management' : 'Pengurusan Teknisi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOnlineSection(eng, bg),
                const SizedBox(height: 20),
                _buildPpmSection(eng, bg),
              ],
            ),
          ),
    );
  }

  Widget _buildOnlineSection(bool eng, Color bg) {
    final onlineCount = _techs.where((t) => t.isOnline).length;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.people_rounded, size: 20, color: Color(0xFF0D7377)),
                const SizedBox(width: 8),
                Text(eng ? 'Technicians' : 'Teknisi',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  tooltip: eng ? 'Add Technician' : 'Tambah Teknisi',
                  onPressed: () => _openAccountScreen(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: onlineCount > 0
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$onlineCount/5 ${eng ? 'Online' : 'Online'}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: onlineCount > 0 ? const Color(0xFF16A34A) : Colors.grey)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._techs.map((t) => _techTile(t, eng)),
        ],
      ),
    );
  }

  Widget _techTile(Technician t, bool eng) {
    final photoUrl = TechService.photoUrl(t);
    final hasPhoto = photoUrl.isNotEmpty && t.photoPath.isNotEmpty;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: t.isOnline ? const Color(0xFF22C55E) : Colors.grey.shade300,
        foregroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
        child: hasPhoto
            ? null
            : Text(t.id, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
      ),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        t.isOnline
          ? (eng ? 'Online' : 'Online')
          : (t.lastSeen.isNotEmpty
              ? '${eng ? "Last seen" : "Terakhir"}: ${t.lastSeen.substring(0, 10)}'
              : (eng ? 'Offline' : 'Luar talian')),
        style: TextStyle(fontSize: 12, color: t.isOnline ? const Color(0xFF16A34A) : Colors.grey),
      ),
      onTap: () => _openAccountScreen(tech: t),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.isOnline ? const Color(0xFF22C55E) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.visibility_rounded, size: 20),
            tooltip: eng ? 'View Dashboard' : 'Lihat Paparan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TechDashboard(techId: t.id)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPpmSection(bool eng, Color bg) {
    if (_ppmItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(eng ? 'PPM data not loaded' : 'Data PPM belum dimuat',
              style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(eng ? 'Retry' : 'Cuba semula'),
            ),
          ],
        ),
      );
    }

    final systems = _ppmItems.map((e) => e.system).toSet().toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.assignment_rounded, size: 20, color: Color(0xFF0D7377)),
                const SizedBox(width: 8),
                Text(eng ? 'PPM Schedule Overview' : 'Ringkasan Jadual PPM',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${_ppmItems.length} tasks',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip(eng ? 'All' : 'Semua', _selectedSystem == null, () => setState(() => _selectedSystem = null)),
                const SizedBox(width: 6),
                ...systems.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _filterChip(s, _selectedSystem == s, () => setState(() => _selectedSystem = s)),
                )),
              ],
            ),
          ),
          ..._buildSystemList(systems, eng),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0D7377) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }

  List<Widget> _buildSystemList(List<String> systems, bool eng) {
    final filtered = _selectedSystem == null
        ? _ppmItems
        : _ppmItems.where((e) => e.system == _selectedSystem).toList();

    final sysMap = <String, List<PpmItem>>{};
    for (final item in filtered) {
      sysMap.putIfAbsent(item.system, () => []).add(item);
    }

    final sorted = sysMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return sorted.take(10).expand((entry) {
      return [
        ListTile(
          dense: true,
          title: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text('${entry.value.length} tasks', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        ),
        const Divider(height: 1, indent: 16),
      ];
    }).toList();
  }
}
