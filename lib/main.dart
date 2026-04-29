import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shared/models/dashboard_state.dart';
import 'shared/theme/app_theme.dart';
import 'features/games/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BoardGameApp());
}

class BoardGameApp extends StatefulWidget {
  const BoardGameApp({super.key});

  @override
  State<BoardGameApp> createState() => _BoardGameAppState();
}

class _BoardGameAppState extends State<BoardGameApp> {
  final _state = DashboardState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archeon',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(state: _state),
    );
  }
}
