import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/loading_screen.dart';
import 'services/telemetry_service.dart';

class GuessImageApp extends StatefulWidget {
  const GuessImageApp({super.key});

  @override
  State<GuessImageApp> createState() => _GuessImageAppState();
}

class _GuessImageAppState extends State<GuessImageApp> with WidgetsBindingObserver {
  static const double _tabletBreakpointDp = 600;

  FlutterView? _view;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(context);
    _updateOrientationLock();
  }

  @override
  void didChangeMetrics() {
    _updateOrientationLock();
  }

  Future<void> _updateOrientationLock() async {
    final view = _view;
    if (view == null) return;

    final display = view.display;
    final shortestSideDp = min(display.size.width, display.size.height) / display.devicePixelRatio;

    if (shortestSideDp >= _tabletBreakpointDp) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      return;
    }

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C5A16),
          brightness: Brightness.light,
          primary: const Color(0xFF7C4D17),
          secondary: const Color(0xFFF1B24A),
          surface: const Color(0xFFFFFBF4),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF6E8),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6B4518),
            side: const BorderSide(color: Color(0xFFCD9E59), width: 1.5),
            backgroundColor: Colors.white.withValues(alpha: 0.64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C4D17),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      navigatorObservers: [
        TelemetryService.instance.analyticsObserver,
      ],
      home: const LoadingScreen(),
    );
  }
}
