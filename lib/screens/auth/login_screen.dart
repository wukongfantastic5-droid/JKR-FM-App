import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/repo_service.dart';
import '../../services/tech_service.dart';
import '../../services/contractor_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/session_service.dart';
import '../../localization.dart';
import '../home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _remember = false;
  String _loginStep = '';

  @override
  void initState() {
    super.initState();
    _restoreRemembered();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Fills the form from the "Remember me" store. This only remembers the
  /// account + password — it never logs the user in automatically.
  Future<void> _restoreRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remember_email') ?? '';
    final pass = prefs.getString('remember_pass') ?? '';
    await prefs.remove('remember_auto');
    if (email.isNotEmpty) _emailCtrl.text = email;
    if (pass.isNotEmpty) _passCtrl.text = pass;
    if (mounted && (email.isNotEmpty || pass.isNotEmpty)) {
      setState(() => _remember = true);
    }
  }

  /// Saves / clears remembered credentials after a successful login.
  Future<void> _persistRemember(String email, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    if (_remember) {
      await prefs.setString('remember_email', email);
      await prefs.setString('remember_pass', pass);
    } else {
      await prefs.remove('remember_email');
      await prefs.remove('remember_pass');
    }
  }

  void _showMaintenanceNotice(bool eng) {
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    setState(() {
      _loading = true;
      _loginStep = 'Checking server status...';
    });
    try {
      await _attempt(email, pass)
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      final step = _loginStep.isEmpty ? 'startup' : _loginStep;
      debugPrint('login failed at [$step]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Login failed at "$step". Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _step(String s) {
    if (mounted) setState(() => _loginStep = s);
  }

  Future<void> _attempt(String email, String pass) async {
    // Maintenance, technician and contractor lookups all run in parallel.
    final downF = MaintenanceService.load();
    final techF = TechService.techLogin(email, pass);
    final contF = ContractorService.load();

    // Maintenance gate: when offline only the admin (Firebase) login works.
    // If it can't be checked quickly, assume online.
    final down = await downF
        .timeout(const Duration(seconds: 8), onTimeout: () => false);

    if (!down) {
      _step('Verifying technician/contractor account...');
      // GitHub lookups get a short budget so a slow connection can never
      // block the admin (Firebase) login below.
      dynamic tech;
      try {
        tech = await techF.timeout(const Duration(seconds: 8));
      } catch (_) {
        tech = null;
      }
      if (tech != null) {
        await _persistRemember(email, pass);
        if (!mounted) return;
        setState(() => _loading = false);
        SessionService.loginAsTech(context, tech.id, tech.name, role: tech.role);
        return;
      }

      // Try contractor accounts (email type: HITACHI@gmail.com, default 123456)
      await RepoService.ensureEnv();
      try {
        await contF.timeout(const Duration(seconds: 8));
      } catch (_) {}
      final contractor = ContractorService.contractorLogin(email, pass);
      if (contractor != null) {
        await _persistRemember(email, pass);
        if (!mounted) return;
        setState(() => _loading = false);
        SessionService.loginAsContractor(context, contractor);
        return;
      }
    }

    _step('Signing in...');
    final err = await AuthService.login(email, pass);
    if (err != null) {
      if (mounted) {
        if (down) {
          _showMaintenanceNotice(LanguageProvider.isEnglish(context));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
      }
      return;
    }
    await _persistRemember(email, pass);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D7377), Color(0xFF0A5C5F)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.build_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'JKR FM GUIDE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_rounded, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => (v?.trim().length ?? 0) >= 2
                        ? null
                        : 'Enter your email or contractor email',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password / Kata laluan',
                      prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => (v?.length ?? 0) >= 6
                        ? null
                        : (eng ? 'Minimum 6 characters' : 'Minimum 6 aksara'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D7377),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _loginStep.isEmpty
                                        ? 'Please wait...'
                                        : _loginStep,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF0D7377)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : const Text('Login',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _remember,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _remember = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.white,
                    checkColor: const Color(0xFF0D7377),
                    title: Text(
                      eng ? 'Remember me' : 'Ingat saya',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _RegisterScreen())),
                    child: Text(
                      eng ? 'Don\'t have account? Register' : 'Takde akaun? Daftar sini',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Web build 2026-08-12 16:05',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterScreen extends StatefulWidget {
  const _RegisterScreen();

  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'technician';
  String _level = '1';
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final err = await AuthService.register(
        _emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim(), _role,
        level: _role == 'complainer' ? _level : null,
      ).timeout(const Duration(seconds: 15));
      setState(() => _loading = false);
      if (err != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration timeout or error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded)),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded)),
                  validator: (v) => v?.contains('@') == true ? null : 'Valid email required',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password (min 6)', prefixIcon: Icon(Icons.lock_rounded)),
                  validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Minimum 6 characters',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_rounded)),
                  validator: (v) => v == _passCtrl.text ? null : 'Passwords do not match',
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_rounded)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _role,
                      isDense: true,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'technician', child: Text('Technician')),
                        DropdownMenuItem(value: 'complainer', child: Text('Complainer')),
                      ],
                      onChanged: _loading ? null : (v) => setState(() => _role = v!),
                    ),
                  ),
                ),
                if (_role == 'complainer') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _level,
                    decoration: const InputDecoration(
                      labelText: 'Level / Aras',
                      prefixIcon: Icon(Icons.layers_rounded),
                    ),
                    items: List.generate(37, (i) => i + 1)
                      .map((f) => DropdownMenuItem(value: '$f', child: Text('Aras $f')))
                      .toList(),
                    onChanged: _loading ? null : (v) => setState(() => _level = v!),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Register', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
