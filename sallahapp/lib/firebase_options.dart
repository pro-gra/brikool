import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;

/// Generated manually from the Firebase console for project
/// "sallahapp-63361". If you ever add iOS, add a matching block below
/// and a case for TargetPlatform.iOS in currentPlatform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have only been configured for web and '
          'android in this manual setup. Add an iOS block here if needed.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDlmEFN2NjlAIa-5LERz5PaYYCRGoj6_xE',
    authDomain: 'sallahapp-63361.firebaseapp.com',
    projectId: 'sallahapp-63361',
    storageBucket: 'sallahapp-63361.firebasestorage.app',
    messagingSenderId: '951073788486',
    appId: '1:951073788486:web:e82566b75dbfebdbadb047',
    measurementId: 'G-QNB8VT9Q3Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCG7Cjn3TI5FJIqW7FQaeP58QGInVQEwpg',
    appId: '1:951073788486:android:e9d38866561ee410adb047',
    messagingSenderId: '951073788486',
    projectId: 'sallahapp-63361',
    storageBucket: 'sallahapp-63361.firebasestorage.app',
  );
}