import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../localization.dart';
import '../providers/theme_provider.dart';
import '../widgets/fade_route.dart';
import '../widgets/prayer_bar.dart';
import '../widgets/http_error_banner.dart';
import '../services/auth_service.dart';
import '../services/repo_service.dart';
import '../services/update_service.dart';
import 'gerak_kerja_screen.dart';
import 'panduan_baikpulih_screen.dart';
import 'fca_screen.dart';
import 'cm_admin_screen.dart';
import 'safe_finding_screen.dart';
import 'slang_screen.dart';
import 'pronunciation_screen.dart';
import 'user_account_screen.dart';
import 'building_view_screen.dart';
import 'inventory_screen.dart';
import 'schedule_screen.dart';
import 'complaint_dashboard_screen.dart';
import 'admin_complaint_screen.dart';
import 'contractor_list_screen.dart';
import 'auth/login_screen.dart';
import 'parts_tools_screen.dart';
import 'analytics_screen.dart';
import 'system_check_screen.dart';
import '../services/maintenance_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _role = 'admin';
  bool _maintDown = false;
  bool _maintBusy = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    RepoService.refresh();
    _loadMaintenance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.check(context);
    });
  }

  Future<void> _confirmLogout(bool eng) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Logout?' : 'Log keluar?'),
        content: Text(eng
            ? 'Are you sure you want to log out?'
            : 'Anda pasti mahu log keluar?'),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role_dummy');
    await prefs.remove('complainer_uid');
    await prefs.remove('complainer_name');
    await prefs.remove('tech_id');
    AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadMaintenance() async {
    final down = await MaintenanceService.load();
    if (mounted) setState(() => _maintDown = down);
  }

  /// Admin-only toggle: online = everything can log in; offline = only admin.
  Future<void> _toggleMaintenance(bool eng) async {
    final target = !_maintDown;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(target
            ? (eng ? 'Go OFFLINE (maintenance)?' : 'Tutup Sistem (maintenance)?')
            : (eng ? 'Back ONLINE?' : 'Kembali ONLINE?')),
        content: Text(target
            ? (eng
                ? 'All users except admin will NOT be able to log in until you switch back online.'
                : 'Semua pengguna selain admin TIDAK boleh log masuk sehingga anda tukar kembali online.')
            : (eng
                ? 'All users will be able to log in again.'
                : 'Semua pengguna boleh log masuk semula.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: target ? Colors.red : const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(target
                ? (eng ? 'Go OFFLINE' : 'Tutup Sistem')
                : (eng ? 'Go ONLINE' : 'Online Semula')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _maintBusy = true);
    final ok = await MaintenanceService.setDown(target);
    if (!mounted) return;
    setState(() {
      _maintBusy = false;
      if (ok) _maintDown = target;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (target
              ? (eng
                  ? 'System now OFFLINE â€” only admin can log in'
                  : 'Sistem kini OFFLINE â€” hanya admin boleh log masuk')
              : (eng ? 'System now ONLINE' : 'Sistem kini ONLINE'))
          : (eng ? 'Update failed â€” retry' : 'Gagal dikemas kini â€” cuba lagi')),
    ));
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final dummy = prefs.getString('user_role_dummy');
    if (dummy != null) {
      if (mounted) setState(() => _role = dummy);
      return;
    }
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      final role = await AuthService.getUserRole(uid);
      if (mounted) setState(() => _role = role ?? 'admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = ThemeProvider.isDark(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.t('appTitle', eng), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              '${AppLocalizations.t('homeSubtitle', eng)} · ${_role.toUpperCase()}',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        actions: [
          if (_role == 'admin') ...[
            _maintBusy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    icon: Icon(
                        _maintDown
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_done_rounded,
                        color: _maintDown ? Colors.amber : Colors.greenAccent),
                    tooltip: eng
                        ? (_maintDown
                            ? 'OFFLINE â€” switch back online'
                            : 'Online â€” switch to maintenance')
                        : (_maintDown
                            ? 'OFFLINE â€” tukar kembali online'
                            : 'Online â€” tukar ke maintenance'),
                    onPressed: () => _toggleMaintenance(eng),
                  ),
            const SizedBox(width: 4),
          ],
          _darkToggle(context, isDark),
          const SizedBox(width: 4),
          _langToggle(context, eng),
          const SizedBox(width: 4),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.troubleshoot_rounded),
            tooltip: eng ? 'System check' : 'Penyemakan sistem',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SystemCheckScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: eng ? 'Settings' : 'Tetapan',
            onPressed: () => _showSettings(context, eng),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: eng ? 'Logout' : 'Log keluar',
            onPressed: () => _confirmLogout(eng),
          ),
        ],
      ),
      body: _role == 'admin' ? _buildAdminBody(eng) : _role == 'complainer' ? _buildComplainerBody(eng) : _buildTechBody(eng),
      ),
    );
  }

  Widget _buildAdminBody(bool eng) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: const PrayerBar(),
        ),
        const HttpErrorBanner(),
        const SizedBox(height: 16),
        Expanded(
          child: RepaintBoundary(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _MainButton(
                  icon: Icons.build_rounded,
                  title: AppLocalizations.t('btnGerakKerja', eng),
                  subtitle: AppLocalizations.t('btnGKSub', eng),
                  color: const Color(0xFF0D7377),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const GerakKerjaScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.construction_rounded,
                  title: AppLocalizations.t('btnBaikpulih', eng),
                  subtitle: AppLocalizations.t('btnBPSub', eng),
                  color: const Color(0xFFE64A19),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const PanduanBaikpulihScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.assignment_rounded,
                  title: 'Senarai FCA (Mechanical)',
                  subtitle: eng ? 'FCA defects list with filters & images' : 'Senarai kecacatan FCA dengan tapis & gambar',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const FcaScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.manage_accounts_rounded,
                  title: eng ? 'User Account' : 'Akaun Pengguna',
                  subtitle: eng
                      ? 'View & login as technician, contractor or complainer accounts'
                      : 'Lihat & log masuk sebagai akaun teknisi, kontraktor atau pengadu',
                  color: const Color(0xFF059669),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserAccountScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.domain_rounded,
                  title: eng ? 'Building View' : 'Paparan Bangunan',
                  subtitle: eng ? '36-level JKR tower with floor-by-floor FCA status' : 'Menara JKR 36 aras dengan status FCA setiap tingkat',
                  color: const Color(0xFF0D7377),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const BuildingViewScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.inventory_2_rounded,
                  title: eng ? 'Asset Inventory' : 'Inventori Aset',
                  subtitle: eng ? 'Full building asset list with add, edit, filter & sort' : 'Senarai aset bangunan dengan tambah, edit, tapis & susun',
                  color: const Color(0xFF4A6741),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const InventoryScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.report_problem_rounded,
                  title: eng ? 'Complaint Management' : 'Pengurusan Aduan',
                  subtitle: eng ? 'View, edit & delete all complaint tickets' : 'Lihat, edit & padam semua tiket aduan',
                  color: const Color(0xFFDC2626),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminComplaintScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.handshake_rounded,
                  title: eng ? 'List of Contractor' : 'Senarai Kontraktor',
                  subtitle: eng ? 'Manage contractor list' : 'Urus senarai kontraktor',
                  color: const Color(0xFF7C3AED),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContractorListScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.handyman_rounded,
                  title: eng ? 'Parts & Tools' : 'Alat Ganti & Perkakas',
                  subtitle: eng ? 'Spare parts & tools stock with suppliers, real-time updates & Word download' : 'Stok alat ganti & perkakas dengan pembekal, kemas kini masa nyata & muat turun Word',
                  color: const Color(0xFF059669),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const PartsToolsScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.construction_rounded,
                  title: eng ? 'Corrective Maintenance (CM)' : 'Penyelenggaraan Pembetulan (CM)',
                  subtitle: eng ? 'Create CM work orders â€” tech closes with before/during/after photos' : 'Buat WO CM â€” teknisi tutup dengan gambar sebelum/semasa/selesai',
                  color: const Color(0xFFC0392B),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const CmAdminScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.security_rounded,
                  title: eng ? 'Safe Finding' : 'Penemuan Keselamatan',
                  subtitle: eng ? 'Safety findings â€” tech records photos, floor, issue & attendance' : 'Penemuan keselamatan â€” teknisi rekod gambar, aras, isu & kehadiran',
                  color: const Color(0xFFB45309),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const SafeFindingScreen(mode: 'admin')),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.calendar_month_rounded,
                  title: eng ? 'PPM Schedule' : 'Jadual PPM',
                  subtitle: eng ? 'Monthly calendar view of PPM tasks for all techs' : 'Kalendar bulanan untuk tugas PPM semua teknisi',
                  color: const Color(0xFF0D7377),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const ScheduleScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _MainButton(
                  icon: Icons.query_stats_rounded,
                  title: eng ? 'Analytics' : 'Analisis',
                  subtitle: eng
                      ? 'Complaint stats, PM reminders & low stock alerts'
                      : 'Statistik aduan, peringatan PM & amaran stok rendah',
                  color: const Color(0xFF6D4C41),
                  onTap: () => Navigator.of(context).push(
                    FadeRoute(page: const AnalyticsScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplainerBody(bool eng) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: const PrayerBar(),
        ),
        const HttpErrorBanner(),
        const SizedBox(height: 16),
        Expanded(
          child: RepaintBoundary(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _MainButton(
                  icon: Icons.report_problem_rounded,
                  title: eng ? 'My Complaints' : 'Aduan Saya',
                  subtitle: eng ? 'View your filed complaint status' : 'Lihat status aduan anda',
                  color: const Color(0xFFDC2626),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ComplaintDashboardScreen()),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechBody(bool eng) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.engineering_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              eng ? 'Technician Dashboard' : 'Paparan Teknisi',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              eng ? 'Your account is registered. Admin will assign tasks to you soon.' : 'Akaun anda telah didaftarkan. Admin akan beri tugasan nanti.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context, bool eng) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(eng ? 'Settings' : 'Tetapan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: const Text('Slang Dictionary'),
              subtitle: const Text('Kelantan word pairs â€” saved to GitHub Repo'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await RepoService.refresh();
                if (!context.mounted) return;
                Navigator.of(context).push(FadeRoute(page: SlangScreen(
                  entries: RepoService.slangEntries,
                  onChanged: (entries) => RepoService.saveSlang(entries),
                )));
              },
            ),
            ListTile(
              leading: const Icon(Icons.hearing_rounded),
              title: const Text('Pronunciation Fix'),
              subtitle: const Text('Fix misheard words â€” "chila" â†’ chiller'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await RepoService.refresh();
                if (!context.mounted) return;
                Navigator.of(context).push(FadeRoute(page: PronunciationScreen(
                  corrections: RepoService.pronunciationCorrections,
                  onChanged: (c) => RepoService.savePronunciationCorrections(c),
                )));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('GitHub Repo Sync'),
              subtitle: const Text('Store data in GitHub Repository Database-JKR'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRepoConfigDialog(context, eng);
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _showRepoConfigDialog(BuildContext context, bool eng) async {
    await RepoService.ensureEnv();
    final tokenCtrl = TextEditingController(text: RepoService.currentToken);
    final ownerCtrl = TextEditingController(text: RepoService.currentOwner);
    final repoCtrl = TextEditingController(text: RepoService.currentRepo);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'GitHub Repo Sync' : 'Segerak Repo GitHub'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tokenCtrl,
                decoration: const InputDecoration(labelText: 'GitHub Personal Token (repo scope)'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ownerCtrl,
                decoration: const InputDecoration(labelText: 'Owner (e.g. wukongfantastic5-droid)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: repoCtrl,
                decoration: const InputDecoration(labelText: 'Repo name (e.g. Database-JKR)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(eng ? 'Cancel' : 'Batal')),
          ElevatedButton(
            onPressed: () async {
              final sm = ScaffoldMessenger.of(context);
              RepoService.setConfig(tokenCtrl.text.trim(), ownerCtrl.text.trim(), repoCtrl.text.trim());
              await RepoService.refresh();
              if (ctx.mounted) Navigator.of(ctx).pop();
              sm.showSnackBar(
                SnackBar(content: Text(eng ? 'Repo config saved!' : 'Konfigurasi repo disimpan!')),
              );
            },
            child: Text(eng ? 'Save' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _langToggle(BuildContext ctx, bool eng) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => LanguageProvider.langNotifier(ctx).value = true,
            child: Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: eng ? Colors.white : Colors.white.withValues(alpha: 0.4))),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => LanguageProvider.langNotifier(ctx).value = false,
            child: Text('BM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: !eng ? Colors.white : Colors.white.withValues(alpha: 0.4))),
          ),
        ],
      ),
    );
  }

  Widget _darkToggle(BuildContext ctx, bool isDark) {
    final e = LanguageProvider.isEnglish(ctx);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: GestureDetector(
        onTap: () => ThemeProvider.themeNotifier(ctx).value = !isDark,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              isDark ? AppLocalizations.t('lightMode', e) : AppLocalizations.t('darkMode', e),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MainButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}