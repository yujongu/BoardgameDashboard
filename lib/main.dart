import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'features/shell/main_shell.dart';

// Set to true ONLY when `firebase emulators:start` is running locally.
// Auth and Functions emulators must BOTH be running, or BOTH be off.
// Mixing emulator auth tokens with production Functions causes INTERNAL errors.
const bool _useEmulators = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (kDebugMode && _useEmulators) {
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    dev.log(
      '[main] Firebase emulators ON — auth:9099, functions:5001, firestore:8080 @ $host',
      name: 'main',
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  } else if (kDebugMode) {
    dev.log('[main] Firebase emulators OFF — using production', name: 'main');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: BoardGameApp()));
}

class BoardGameApp extends StatefulWidget {
  const BoardGameApp({super.key});

  @override
  State<BoardGameApp> createState() => _BoardGameAppState();
}

class _BoardGameAppState extends State<BoardGameApp> {
  String? _profileSetupUid;

  Widget _buildHome(User? user) {
    if (user == null) {
      _profileSetupUid = null;
      return const LoginScreen();
    }

    final hasName =
        user.uid == _profileSetupUid ||
        (user.displayName != null && user.displayName!.isNotEmpty);

    if (!hasName) {
      return ProfileSetupScreen(
        onComplete: () => setState(() => _profileSetupUid = user.uid),
      );
    }

    return const MainShell();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gameshelf',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (snapshot.hasError) {
            return const _SplashScreen();
          }
          return _buildHome(snapshot.data);
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: kColorPrimary)),
    );
  }
}
