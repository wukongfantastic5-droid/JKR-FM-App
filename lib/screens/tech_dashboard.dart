import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../services/auth_service.dart';
import '../services/tech_service.dart';
import '../services/cm_service.dart';
import '../widgets/http_error_banner.dart';
import '../data/technician_data.dart';
import 'tech_account_screen.dart';
import 'schedule_screen.dart';
import 'pm_task_screen.dart';
import 'cm_task_screen.dart';
import 'auth/login_screen.dart';                            
import '../services/pm_status_service.dart';                
import 'tech_parts_tools_screen.dart';
import 'safe_finding_screen.dart';

class TechDashboard extends StatefulWidget {
  final String techId;
  const TechDashboard({super.key, required this.techId});

  @override
  State<TechDashboard> createState() => _TechDashboardState();
}

class _TechDashboardState extends State<TechDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ScheduleTask> _todaySchedule = [];
  Map<String, List<ScheduleTask>> _bySystem = {};
  List<String> _sysOrder = [];
  final Set<String> _sysOpen = {};
  int _monthCount = 0;
  int _upcomingCount = 0;
  bool _loading = true;
  String _techName = '';
  DateTime? _demoDate;

  // Systems handled by subcontractors: technician only sees D + W tasks.
  // 1.0 ACMV (CARRIER/IGSP/SDC), 2.0 Fire Fighting (SEMARAK),
  // 3.0 Lift (HITACHI), 4.0 Gondola (ALIMAK). 5.0+ are done by our own
  // technicians on the full schedule.
  static const Set<String> _contracted = {'1.0', '2.0', '3.0', '4.0'};

  static const List<Color> _sysPalette = [
    Color(0xFF0D7377),
    Color(0xFF1565C0),
    Color(0xFF7B1FA2),
    Color(0xFFE64A19),
    Color(0xFF4A6741),
    Color(0xFFC62828),
    Color(0xFF6D4C41),
    Color(0xFF283593),
    Color(0xFF00838F),
  ];

  bool _isContracted(String sys) => _contracted.contains(sys.split(' ').first.trim());

  int _sysIndex(String sys) {
    final order = SysOrder.indexOf(sys.split(' ').first.trim());
    return order == -1 ? 8 : order;
  }

  Color _sysColor(String sys) => _sysPalette[_sysIndex(sys) % _sysPalette.length];

  static const List<String> SysOrder = [
    '1.0', '2.0', '3.0', '4.0', '5.0', '6.0', '7.0', '8.0', '9.0',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _techName = prefs.getString('tech_name_${widget.techId}') ?? 'Technician ${widget.techId}';

    final months = await TechService.loadPpmSchedule();
    final now = _demoDate ?? DateTime.now();
    final monthKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
    final todayIso = '$monthKey-${now.day.toString().padLeft(2, '0')}';

    // Load real (or demo) PM statuses so closed tasks disappear for that day.
    await TechService.loadTechStatus();
    PmStatusService.demoMode = _demoDate != null;
    await PmStatusService.load();
    final closedIds = PmStatusService.closedIdsOn(todayIso);

    final today = <ScheduleTask>[];
    var monthCount = 0;
    var upcomingCount = 0;
    final start = DateTime(now.year, now.month, now.day);
    final end = now.add(const Duration(days: 30));

    for (final m in months) {
      var isCurrent = false;
      if (m.month == monthKey) isCurrent = true;
      for (final row in m.rows) {
        final contracted = _isContracted(row.sys);

        if (isCurrent) {
          for (final e in row.cells.entries) {
            if (contracted) {
              if (e.value.any((mk) => mk == 'D' || mk == 'W')) monthCount++;
            } else {
              monthCount++;
            }
          }
        }

        final ms = row.cells[todayIso];
        if (ms != null && ms.isNotEmpty) {
          final markers = contracted
              ? ms.where((mk) => mk == 'D' || mk == 'W').toList()
              : ms.toList();
          if (markers.isNotEmpty || !contracted) {
            today.add(ScheduleTask(
              sys: row.sys,
              sub: row.sub,
              item: row.item,
              desc: row.desc,
              freq: row.freq,
              markers: markers,
            ));
          }
        }
        if (!isCurrent) {
          for (final e in row.cells.entries) {
            final d = DateTime.tryParse(e.key);
            if (d == null || d.isBefore(start) || d.isAfter(end)) continue;
            if (contracted && !e.value.any((mk) => mk == 'D' || mk == 'W')) continue;
            upcomingCount++;
          }
        }
      }
    }
    _todaySchedule = today.where((t) {
      final taskId = PmStatusService.buildId(
          date: todayIso, sys: t.sys, item: t.item, desc: t.desc);
      return !closedIds.contains(taskId);
    }).toList();
    _monthCount = monthCount;
    _upcomingCount = upcomingCount;

    final bySystem = <String, List<ScheduleTask>>{};
    for (final t in _todaySchedule) {
      bySystem.putIfAbsent(t.sys, () => []).add(t);
    }
    final order = List.of(bySystem.keys)
      ..sort((a, b) => _sysIndex(a).compareTo(_sysIndex(b)));
    _bySystem = bySystem;
    _sysOrder = order;
    for (final s in order) {
      _sysOpen.add(s);
    }

    await TechService.loadTechStatus();
    for (final t in TechService.technicians) {
      if (t.id == widget.techId) {
        _techName = t.name;
        await prefs.setString('tech_name_${widget.techId}', t.name);
      }
    }
    await TechService.setTechOnline(widget.techId, true);

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openSettings() async {
    await TechService.loadTechStatus();
    Technician? tech;
    for (final t in TechService.technicians) {
      if (t.id == widget.techId) tech = t;
    }
    if (tech == null) {
      tech = Technician(id: widget.techId);
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TechAccountScreen(existing: tech)),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _logout() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Logout?' : 'Log keluar?'),
        content: Text(eng
            ? 'Are you sure you want to log out?'
            : 'Anda pasti yakin mahu log keluar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Logout' : 'Log keluar'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await TechService.setTechOnline(widget.techId, false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tech_id');
    await prefs.remove('tech_name_${widget.techId}');
    await prefs.remove('user_role_dummy');
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_techName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(eng ? 'Technician Dashboard' : 'Paparan Teknisi',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: eng ? 'Settings / Edit Profile' : 'Tetapan / Edit Profil',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: eng ? 'Logout' : 'Log keluar',
            onPressed: _logout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) {
              final tabs = [
                _tabPill(eng ? 'PPM' : 'PPM', Icons.calendar_month_rounded, const Color(0xFF2196F3), 0),
                _tabPill('CM', Icons.construction_rounded, const Color(0xFFE64A19), 1),
                _tabPill(eng ? 'Schedule' : 'Jadual', Icons.event_note_rounded, const Color(0xFF00897B), 2),
                _tabPill(eng ? 'On-Call' : 'Panggilan', Icons.phone_in_talk_rounded, const Color(0xFFF9A825), 3),
                _tabPill(eng ? 'Parts & Tools' : 'Alat Ganti & Perkakas', Icons.handyman_rounded, const Color(0xFF7B1FA2), 4),
                _tabPill(eng ? 'Safe Finding' : 'Penemuan Keselamatan', Icons.security_rounded, const Color(0xFFB45309), 5),
              ];
              return TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                tabs: tabs,
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          const HttpErrorBanner(),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildPpmTab(eng),
                    _buildCmTab(eng),
                    const ScheduleScreen(embedded: true),
                    _buildOnCallTab(eng),
                    _buildPartsToolsLauncher(eng),
                    _buildSafeFindingLauncher(eng),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartsToolsLauncher(bool eng) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: .25)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TechPartsToolsScreen(techId: widget.techId),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.handyman_rounded,
                    size: 44,
                    color: const Color(0xFF7B1FA2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    eng ? 'Parts & Tools' : 'Alat Ganti & Perkakas',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eng
                        ? 'Spare parts, tools & status usage — tap to open'
                        : 'Alat ganti, perkakas & kegunaan — tekan untuk buka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeFindingLauncher(bool eng) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: .25)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SafeFindingScreen(
                  mode: 'tech',
                  techId: widget.techId,
                  techName: _techName,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 44,
                    color: const Color(0xFFB45309),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    eng ? 'Safe Finding' : 'Penemuan Keselamatan',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eng
                        ? 'Record safety findings — photo, floor, issue & report — tap to open'
                        : 'Rekod penemuan keselamatan — gambar, aras, isu & laporan — tekan untuk buka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPpmTab(bool eng) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Stack(
        children: [
          _todaySchedule.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(eng ? 'No PPM tasks today' : 'Tiada tugas PPM hari ini',
                            style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 12),
                          _buildInfoCards(eng),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildInfoCards(eng),
                  _buildTodayHeader(eng),
                  _buildDemoBanner(eng),
                  ..._sysOrder.map((s) => _buildSystemSection(eng, s)),
                ],
              ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(child: _buildDemoButton(eng)),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoBanner(bool eng) {
    if (_demoDate == null) return const SizedBox.shrink();
    final now = _demoDate!;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final wdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${wdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_rounded, size: 14, color: Color(0xFFB45309)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${eng ? 'DEMO MODE Â· Previewing' : 'MODE DEMO Â· Pratinjau'} $dateStr',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _demoDate = null);
              _load();
            },
            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDemoDate(bool eng) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _demoDate ?? DateTime(2026, 8, 10),
      firstDate: DateTime(2026, 7, 1),
      lastDate: DateTime(2031, 12, 31),
      helpText: eng ? 'Pick a date to preview PPM' : 'Pilih tarikh untuk pratinjau PPM',
    );
    if (picked != null) {
      setState(() => _demoDate = picked);
      await _load();
    }
  }

  Widget _buildDemoButton(bool eng) {
    return GestureDetector(
      onTap: () => _pickDemoDate(eng),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: _demoDate == null
              ? const Color(0xFF0D7377).withValues(alpha: 0.9)
              : const Color(0xFFF59E0B).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(2, 2))],
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_demoDate == null ? Icons.event_rounded : Icons.visibility_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text(_demoDate == null ? (eng ? 'DEMO DATE' : 'TARIKH DEMO') : (_demoDateText()),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  String _demoDateText() {
    final d = _demoDate!;
    return '${d.day}/${d.month}/${d.year}';
  }

  Widget _buildTodayHeader(bool eng) {
    final now = _demoDate ?? DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final wdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr = '${wdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_rounded, size: 16, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          Text(eng ? 'PPM Today Â· $dateStr' : 'PPM Hari Ini Â· $dateStr',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_todaySchedule.length}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D7377))),
        ],
      ),
    );
  }

  Widget _buildInfoCards(bool eng) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(child: _statCard(Icons.today_rounded, '${_todaySchedule.length}', eng ? 'Today' : 'Hari ini', const Color(0xFF0D7377))),
          const SizedBox(width: 8),
          Expanded(child: _statCard(Icons.calendar_month_rounded, '$_monthCount', eng ? 'This Month' : 'Bulan Ini', const Color(0xFFF59E0B))),
          const SizedBox(width: 8),
          Expanded(child: _statCard(Icons.event_rounded, '$_upcomingCount', eng ? 'Upcoming' : 'Akan Datang', const Color(0xFF3B82F6))),
        ],
      ),
    );
  }

  Widget _buildSystemSection(bool eng, String sys) {
    final tasks = _bySystem[sys] ?? const [];
    final color = _sysColor(sys);
    final contracted = _isContracted(sys);
    final open = _sysOpen.contains(sys);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: color.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => setState(() {
              if (open) {
                _sysOpen.remove(sys);
              } else {
                _sysOpen.add(sys);
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(sys,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (contracted)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E9E9E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('SUB',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                  const SizedBox(width: 6),
                  Text('${tasks.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ],
              ),
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 4),
          ...tasks.map((t) => _scheduleCard(t, eng, color)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildCmTab(bool eng) {
    return CmListView(techId: widget.techId, techName: _techName);
  }

  Widget _tabPill(String label, IconData icon, Color color, int index) {
    final sel = _tabCtrl.index == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: sel ? color : color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sel ? color : color.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: sel ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
              color: sel ? Colors.white : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _taskDateIso() {
    final now = _demoDate ?? DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openTask(ScheduleTask t) async {
    final wasDemo = _demoDate != null;
    PmStatusService.demoMode = wasDemo;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PmTaskScreen(
          date: _taskDateIso(),
          sys: t.sys,
          sub: t.sub,
          item: t.item,
          desc: t.desc,
          freq: t.freq,
          markers: t.markers,
          techId: widget.techId,
          techName: _techName,
        ),
      ),
    );
    PmStatusService.demoMode = false;
    if (changed == true) await _load();
  }

  Widget _scheduleCard(ScheduleTask task, bool eng, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTask(task),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(width: 3, height: 36, decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(taskTitle(task),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(taskSub(task),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Wrap(
                spacing: 3,
                children: task.markers.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _markerColor(m),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(m, style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const Map<String, Color> _markerColors = {
    'D': Color(0xFF1D6FB8),
    'W': Color(0xFF1B8A5A),
    'M': Color(0xFFE07B39),
    '3M': Color(0xFF8E44AD),
    '6M': Color(0xFFC0392B),
    'Y': Color(0xFF4A4A4A),
    '2Y': Color(0xFF00838F),
    '5Y': Color(0xFF6D4C41),
  };

  Color _markerColor(String m) => _markerColors[m] ?? Colors.grey.shade600;

  String taskTitle(ScheduleTask t) {
    final parts = <String>[];
    if (t.item.isNotEmpty) parts.add(t.item);
    if (t.desc.isNotEmpty) parts.add(t.desc);
    final main = parts.join(' ');
    if (main.isEmpty) return t.sys;
    return main;
  }

  String taskSub(ScheduleTask t) {
    final parts = <String>[t.sys];
    if (t.sub.isNotEmpty) parts.add(t.sub);
    return parts.join(' Â· ');
  }

  Widget _buildOnCallTab(bool eng) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.phone_in_talk_rounded, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(eng ? 'On-Call Duty' : 'Tugas Panggilan',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                eng ? 'Mark yourself available for on-call emergency repair.'
                    : 'Tanda diri sedia untuk baiki kecemasan.',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(eng ? 'You are now on-call' : 'Anda kini dalam panggilan'),
                  ));
                },
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(eng ? 'I\'m Available' : 'Saya Sedia'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eng ? 'Contact Admin' : 'Hubungi Admin',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                leading: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF0D7377)),
                title: const Text('018-XXX XXXX'),
                subtitle: Text(eng ? 'Admin phone' : 'Telefon admin'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class CmListView extends StatefulWidget {
  final String techId;
  final String techName;
  const CmListView({super.key, required this.techId, required this.techName});

  @override
  State<CmListView> createState() => _CmListViewState();
}

class _CmListViewState extends State<CmListView> {
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      CmService.load();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CmService.load();
    if (mounted) setState(() => _loading = false);
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final list = List<CmWorkOrder>.from(CmService.entries.where((e) => !e.isClosed))
      ..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading && list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 16, color: const Color(0xFF0D7377)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eng
                              ? 'Live â€” updates automatically every few seconds'
                              : 'Masa nyata â€” dikemas kini automatik setiap beberapa saat',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0D7377)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 140),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          eng ? 'No CM work orders yet' : 'Tiada WO CM lagi',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          eng ? 'Admin will assign CM tasks here when needed.' : 'Admin akan beri tugas CM di sini bila perlu.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...list.map((wo) => _card(wo, eng)),
              ],
            ),
    );
  }

  Widget _card(CmWorkOrder wo, bool eng) {
    final (color, label) = wo.isClosed
        ? (const Color(0xFF16A34A), eng ? 'CLOSED' : 'SELESAI')
        : wo.isInProgress
            ? (const Color(0xFFF59E0B), eng ? 'IN PROGRESS' : 'SEDANG DIJALANKAN')
            : (const Color(0xFFEF4444), eng ? 'OPEN' : 'TERBUKA');
    final mine = wo.techId.isNotEmpty && wo.techId == widget.techId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CmTaskScreen(
                woId: wo.id,
                techId: widget.techId,
                techName: widget.techName,
              ),
            ),
          );
          if (changed == true) {
            await CmService.load();
            if (mounted) setState(() {});
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7377).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(eng ? 'MINE' : 'SAYA',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF0D7377))),
                    ),
                  ],
                  const Spacer(),
                  Text(wo.id,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ],
              ),
              const SizedBox(height: 8),
              Text(wo.defect, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(_fmtDate(wo.date),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Icon(Icons.layers_rounded, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(wo.floor, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
              if (wo.techName.isNotEmpty && !mine) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${eng ? 'Taken by' : 'Diambil oleh'}: ${wo.techName}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
