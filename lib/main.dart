import 'dart:async';
import 'dart:io' show Platform, stdout, exit;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'localization.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/prayer_times_service.dart';
import 'services/firebase_config.dart';
import 'services/update_service.dart';
import 'services/repo_service.dart';
import 'services/pm_status_service.dart';
import 'widgets/app_footer.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Console self-test (used on Windows to verify the app talks to the real
/// GitHub database): set SELFTEST=1 in the environment, run the exe, read
/// PASS/FAIL on stdout. Exercises the exact service code paths the UI uses.
Future<int> runSelfTest() async {
  stdout.writeln('JKR FM Guide self-test (db: ${RepoService.currentOwner}/${RepoService.currentRepo})');
  try {
    await RepoService.ensureEnv();
    if (RepoService.currentToken.isEmpty) {
      stdout.writeln('SELF TEST FAIL: no GitHub token bundled');
      return 1;
    }
    final probe = await RepoService.diagnostics();
    stdout.writeln('apiReachable=${probe['apiReachable']} tokenAuth=${probe['tokenAuth']}');
    if ('${probe['apiReachable']}'.startsWith('2') == false) {
      stdout.writeln('SELF TEST FAIL: api.github.com unreachable');
      return 1;
    }

    final writeVerdict = await RepoService.testWrite();
    stdout.writeln('testWrite -> $writeVerdict');
    if (!writeVerdict.startsWith('WRITE OK')) {
      stdout.writeln('SELF TEST FAIL: write failed');
      return 1;
    }

    final pm = PmStatusService();
    await PmStatusService.load();
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final e = PmStatusService.entryFor(
      date: date,
      sys: 'SELFTEST',
      item: 'SELFTEST-ITEM',
      desc: 'automated self test ${now.millisecondsSinceEpoch}',
    );
    final attended = await PmStatusService.attend(e, 'selftest', 'Self Test');
    stdout.writeln('pm.attend -> $attended (id ${e.id})');
    var found = false;
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(seconds: 1));
      await PmStatusService.load();
      found = PmStatusService.entries.any((x) => x.id == e.id);
      if (found) break;
    }
    if (!found || !attended) {
      stdout.writeln('SELF TEST FAIL: PM attend not persisted');
      return 1;
    }
    stdout.writeln('pm attend persisted in database OK');
    await PmStatusService.removeEntry(e);
    await PmStatusService.load();
    stdout.writeln('SELF TEST PASS');
    return 0;
  } catch (err) {
    stdout.writeln('SELF TEST FAIL: $err');
    return 1;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(isOptional: true);
  } catch (e) {
    debugPrint('dotenv load skipped: $e');
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows &&
      Platform.environment.containsKey('SELFTEST')) {
    exit(await runSelfTest());
  }
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: FirebaseConfig.webOptions);
    } else if (defaultTargetPlatform == TargetPlatform.android ||
               defaultTargetPlatform == TargetPlatform.iOS) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(options: FirebaseConfig.desktopOptions);
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const JkrFmGuideApp());
}

class JkrFmGuideApp extends StatefulWidget {
  const JkrFmGuideApp({super.key});

  @override
  State<JkrFmGuideApp> createState() => _JkrFmGuideAppState();
}

/// Checks for app updates once per launch, for EVERY account type
/// (admin, technician, complainer, contractor), regardless of which
/// screen they land on after login.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_checked || !mounted) return;
      _checked = true;
      UpdateService.check(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _JkrFmGuideAppState extends State<JkrFmGuideApp> {
  final ValueNotifier<bool> _isEnglish = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isDark = ValueNotifier<bool>(false);
  final GlobalKey<ScaffoldMessengerState> _smKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _prayerTimer;
  final Set<String> _notifiedToday = {};

  @override
  void initState() {
    super.initState();
    _prayerTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkPrayerAlert());
  }

  @override
  void dispose() {
    _isEnglish.dispose();
    _isDark.dispose();
    _prayerTimer?.cancel();
    super.dispose();
  }

  void _checkPrayerAlert() {
    PrayerTimesService.getToday().then((prayerTimes) {
      final soon = PrayerTimesService.prayerSoonIn15Mins(prayerTimes);
      if (soon != null && !_notifiedToday.contains(soon)) {
        _notifiedToday.add(soon);
        final eng = _isEnglish.value;
        final prayerName = AppLocalizations.t('prayer${soon[0].toUpperCase()}${soon.substring(1)}', eng);
        final msg = AppLocalizations.t('prayerSoon', eng).replaceFirst('{prayer}', prayerName);
        _smKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: const Color(0xFF0D7377),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      final todayDate = DateTime.now().toUtc().add(const Duration(hours: 8));
      if (todayDate.hour == 0 && todayDate.minute == 0) {
        _notifiedToday.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_isEnglish, _isDark]),
      builder: (context, _) {
        return MaterialApp(
          title: 'JKR FM Guide',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _smKey,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: _isDark.value ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return LanguageProvider(
              notifier: _isEnglish,
              child: ThemeProvider(
                notifier: _isDark,
                child: UpdateGate(
                  child: Stack(
                    children: [
                      child!,
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: CopyrightBar(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          home: Firebase.apps.isNotEmpty
              ? StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SplashScreen();
                    }
                    if (snapshot.data != null) {
                      return const HomeScreen();
                    }
                    return const LoginScreen();
                  },
                )
              : const LoginScreen(),
        );
      },
    );
  }
}
