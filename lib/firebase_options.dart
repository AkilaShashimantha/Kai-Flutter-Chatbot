import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'This platform is not supported by the current Firebase configuration.',
        );
    }
  }

  // Web config (from Firebase CLI sdkconfig)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCWntmF93nUeCUqOpGuKbjBgFaAD8_sjpg',
    appId: '1:802422113532:web:f772233c514bf3e7ff8379',
    messagingSenderId: '802422113532',
    projectId: 'flutter-chatbot-f8160',
    authDomain: 'flutter-chatbot-f8160.firebaseapp.com',
    storageBucket: 'flutter-chatbot-f8160.firebasestorage.app',
    measurementId: 'G-8RYDR7FDV8',
  );

  // Android config (from android/app/google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBDPwVza0VrC5BwXGt3guYF3I1jcivqiZ0',
    appId: '1:802422113532:android:010bc32df164ac57ff8379',
    messagingSenderId: '802422113532',
    projectId: 'flutter-chatbot-f8160',
    storageBucket: 'flutter-chatbot-f8160.firebasestorage.app',
  );
}
