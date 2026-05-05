// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBe3oYiBHCpRKJd0jLoAhkXKepwfdFa0BU',
    appId: '1:295999324490:android:223231a8b638fa3b8e81b3',
    messagingSenderId: '295999324490',
    projectId: 'gameshelf-283dc',
    storageBucket: 'gameshelf-283dc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAknhWsRTH2m-lwfJ3wFvkHLWPFikYRe9E',
    appId: '1:295999324490:ios:3d8fa77f031e146d8e81b3',
    messagingSenderId: '295999324490',
    projectId: 'gameshelf-283dc',
    storageBucket: 'gameshelf-283dc.firebasestorage.app',
    iosBundleId: 'com.yujongu.boardGameDashboard',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAknhWsRTH2m-lwfJ3wFvkHLWPFikYRe9E',
    appId: '1:295999324490:ios:3d8fa77f031e146d8e81b3',
    messagingSenderId: '295999324490',
    projectId: 'gameshelf-283dc',
    storageBucket: 'gameshelf-283dc.firebasestorage.app',
    iosBundleId: 'com.yujongu.boardGameDashboard',
  );
}
