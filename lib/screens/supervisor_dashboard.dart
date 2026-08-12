import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../services/auth_service.dart';
import '../services/tech_service.dart';
import '../widgets/http_error_banner.dart';
import 'cm_admin_screen.dart';
import 'schedule_screen.dart';
import 'auth/login_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  final String techId;
  final String techName;
  const SupervisorDashboard({super.key, required this.techId, required this.techName});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _name = widget.techName;
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString('tech_name_${widget.techId}');
    if (n != null && n.isNotEmpty && mounted) setState(() => _name = n);
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
    AuthService.logout();
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
            Text(_name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              eng ? 'SUPERVISOR Dashboard' : 'Paparan PENYELIA',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: eng ? 'Logout' : 'Log keluar',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          const HttpErrorBanner(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _MainButton(
                    icon: Icons.assignment_rounded,
                    title: eng ? 'Corrective Maintenance (CM)' : 'Penyelenggaraan Pembetulan (CM)',
                    subtitle: eng
                        ? 'Create, edit, delete & close CM work orders with Word reports (real-time)'
                        : 'Buat, edit, padam & tutup WO CM dengan laporan Word (masa nyata)',
                    color: const Color(0xFFC0392B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CmAdminScreen(
                          canClose: true,
                          closeTechId: widget.techId,
                          closeTechName: _name,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MainButton(
                    icon: Icons.calendar_month_rounded,
                    title: eng ? 'PPM Schedule' : 'Jadual PPM',
                    subtitle: eng
                        ? 'Monthly calendar view of PPM tasks for all techs'
                        : 'Kalendar bulanan untuk tugas PPM semua teknisi',
                    color: const Color(0xFF0D7377),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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