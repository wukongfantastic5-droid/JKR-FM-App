import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  /// Real Android app values from android\app\google-services.json (works for
  /// Windows desktop auth, which calls the same Firebase REST API).
  static FirebaseOptions get desktopOptions => const FirebaseOptions(
    apiKey: 'AIzaSyD3F4dIVk5-KmvHCd691Qt2r1xJVK1bK6Q',
    appId: '1:1095672010363:android:e1abd0767aa15bbe4ff4de',
    messagingSenderId: '1095672010363',
    projectId: 'jkr-database',
    authDomain: 'jkr-database.firebaseapp.com',
    storageBucket: 'jkr-database.firebasestorage.app',
  );
}