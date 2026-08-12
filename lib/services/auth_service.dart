import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'firebase_config.dart';

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
      if (kIsWeb) {
        return await _registerWeb(email, password, name, role, level: level);
      } else {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password,
        ).timeout(const Duration(seconds: 15));
        await _prefs!.setString('user_role_${cred.user!.uid}', role);
        await _prefs!.setString('user_name_${cred.user!.uid}', name);
        if (role == 'complainer' && level != null) {
          await _prefs!.setString('user_level_${cred.user!.uid}', level);
        }
        return null;
      }
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

  static Future<String?> _registerWeb(String email, String password, String name, String role, {String? level}) async {
    final resp = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp'
          '?key=${FirebaseConfig.webOptions.apiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      final msg = data['error']?['message'] as String? ?? 'HTTP ${resp.statusCode}';
      return 'API error: $msg';
    }
    final localId = data['localId'] as String;
    await _auth.signInWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    ).timeout(const Duration(seconds: 15));
    await _ensurePrefs();
    await _prefs!.setString('user_role_$localId', role);
    await _prefs!.setString('user_name_$localId', name);
    if (role == 'complainer' && level != null) {
      await _prefs!.setString('user_level_$localId', level);
    }
    return null;
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
