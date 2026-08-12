import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  /// Verified against build\web\main.dart.js (compiled from original source).
  static FirebaseOptions get webOptions => const FirebaseOptions(
    apiKey: 'AIzaSyCrK2zoLQ_xybwmXitVl3kAV4rtl4jb3sU',
    appId: '1:1095672010363:web:84b233654eb8ab354ff4de',
    messagingSenderId: '1095672010363',
    projectId: 'jkr-database',
    authDomain: 'jkr-database.firebaseapp.com',
    storageBucket: 'jkr-database.firebasestorage.app',
  );

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