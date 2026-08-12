import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/contractor_data.dart';
import '../localization.dart';
import '../screens/contractor_dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/supervisor_dashboard.dart';
import '../screens/tech_dashboard.dart';
import 'maintenance_service.dart';

/// Shared "switch account" helpers used by the login screen and the admin
/// User Account screen (impersonation). Each logs the current session in as
/// the selected account and navigates to that account's full dashboard.
class SessionService {
  static void _maintenanceNotice(BuildContext context, bool eng) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.construction_rounded,
            size: 40, color: Color(0xFFB45309)),
        title: Text(eng
            ? 'Server under maintenance'
            : 'Server sedang diselenggara'),
        content: Text(eng
            ? 'The system is currently under maintenance. Only the admin can log in right now. Please try again later.'
            : 'Sistem sedang dalam penyelenggaraan. Hanya admin boleh log masuk sekarang. Sila cuba lagi kemudian.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(eng ? 'OK' : 'OK')),
        ],
      ),
    );
  }

  static Future<bool> _maintenanceBlocked(BuildContext context) async {
    if (await MaintenanceService.load()) {
      if (context.mounted) {
        _maintenanceNotice(context, LanguageProvider.isEnglish(context));
      }
      return true;
    }
    return false;
  }

  static Future<void> loginAsTech(
      BuildContext context, String techId, String techName,
      {String role = 'technician'}) async {
    if (await _maintenanceBlocked(context)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tech_id', techId);
    await prefs.setString('tech_name_$techId', techName);
    await prefs.setString('user_role_dummy', role == 'supervisor' ? 'supervisor' : 'technician');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      role == 'supervisor'
          ? MaterialPageRoute(
              builder: (_) => SupervisorDashboard(techId: techId, techName: techName))
          : MaterialPageRoute(builder: (_) => TechDashboard(techId: techId)),
      (route) => false,
    );
  }

  static Future<void> loginAsContractor(BuildContext context, Contractor c) async {
    if (await _maintenanceBlocked(context)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contractor_id', c.id);
    await prefs.setString('contractor_name', c.name);
    await prefs.setString('user_role_dummy', 'contractor');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => ContractorDashboardScreen(contractor: c)),
      (route) => false,
    );
  }

  static Future<void> loginAsComplainer(
      BuildContext context,
      {required String uid,
      required String name,
      String level = ''}) async {
    if (await _maintenanceBlocked(context)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role_dummy', 'complainer');
    await prefs.setString('complainer_uid', uid);
    await prefs.setString('complainer_name', name);
    if (level.isNotEmpty) {
      await prefs.setString('complainer_level', level);
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}