import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'shared/theme/app_colors.dart';
import 'shared/providers/theme_mode_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'features/shell/main_shell.dart';

// Enable the Firebase Emulator Suite with --dart-define=USE_EMULATORS=true
// (defaults to false → production, so normal runs are unaffected). Auth and
// Functions emulators must BOTH be running, or BOTH be off — mixing emulator
// auth tokens with production Functions causes INTERNAL errors. The integration
// test suite passes this define so it never touches production.
const bool _useEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Crashlytics — Android/iOS/macOS only (not web/Windows/Linux). Collection is
  // disabled in debug/emulator runs so local crashes never reach production.
  final crashlyticsOn =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (crashlyticsOn) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode && !_useEmulators,
    );
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (kDebugMode) defaultOnError?.call(details); // keep the console dump
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Tag crashes with the current user (no PII).
    FirebaseAuth.instance.authStateChanges().listen(
      (user) => FirebaseCrashlytics.instance.setUserIdentifier(user?.uid ?? ''),
    );
  }

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

class BoardGameApp extends ConsumerStatefulWidget {
  const BoardGameApp({super.key});

  @override
  ConsumerState<BoardGameApp> createState() => _BoardGameAppState();
}

class _BoardGameAppState extends ConsumerState<BoardGameApp> {
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
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (snapshot.hasError) {
            return _AuthErrorScreen(error: snapshot.error!);
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
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      ),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  final Object error;

  const _AuthErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: context.colors.primary,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.of(context).authErrorTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
