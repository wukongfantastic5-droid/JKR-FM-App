import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static bool _ready = false;
  static SharedPreferences? _prefs;

  static Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<bool> ensureReady() async {
    if (_ready) return true;
    if (Firebase.apps.isEmpty) return false;
    _ready = true;
    return true;
  }

  static FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) throw Exception('Firebase not initialized');
    return FirebaseAuth.instance;
  }

  static Future<String?> register(String email, String password, String name, String role, {String? level}) async {
    try {
      final ready = await ensureReady();
      if (!ready) return 'Firebase not initialized. Check config.';
      await _ensurePrefs();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      ).timeout(const Duration(seconds: 15));
      await _prefs!.setString('user_role_${cred.user!.uid}', role);
      await _prefs!.setString('user_name_${cred.user!.uid}', name);
      if (role == 'complainer' && level != null) {
        await _prefs!.setString('user_level_${cred.user!.uid}', level);
      }
      return null;
    } on TimeoutException catch (_) {
      return '⏱ Timed out after 15s. Check: (1) Firebase Auth enabled (2) Network';
    } on FirebaseAuthException catch (e) {
      return 'Auth error: ${e.message} (code: ${e.code})';
    } on FirebaseException catch (e) {
      return 'Firebase error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<String?> login(String email, String password) async {
    try {
      await ensureReady();
      await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      ).timeout(const Duration(seconds: 10));
      return null;
    } on TimeoutException catch (_) {
      return 'Login timed out. Check network connection.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } on FirebaseException catch (e) {
      return 'Firebase error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<void> logout() async {
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
    }
  }

  static User? get currentUser {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser;
  }

  static Future<String?> getUserRole(String uid) async {
    try {
      await _ensurePrefs();
      return _prefs!.getString('user_role_$uid') ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  static Stream<User?> get authState {
    if (Firebase.apps.isEmpty) return const Stream.empty();
    return FirebaseAuth.instance.authStateChanges();
  }
}
