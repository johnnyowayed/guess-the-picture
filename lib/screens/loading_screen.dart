import 'dart:async';

import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../services/level_service.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';
import 'game_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const int _initialPreloadCount = 3;
  static const double _warmupTarget = 0.12;

  final LevelService _levelService = LevelService();
  final StorageService _storageService = StorageService();

  double _progress = 0;
  double _targetProgress = 0;
  String? _error;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _startProgressAnimation();
    _preloadImages();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressAnimation() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final next = _progress + ((_targetProgress - _progress) * 0.14);
      if ((next - _progress).abs() < 0.001) {
        if (_progress != _targetProgress) {
          setState(() {
            _progress = _targetProgress;
          });
        }
        return;
      }
      setState(() {
        _progress = next.clamp(0.0, 1.0);
      });
    });
  }

  void _setProgressTarget(double value) {
    _targetProgress = value.clamp(0.0, 1.0);
  }

  Future<void> _preloadImages() async {
    try {
      _setProgressTarget(_warmupTarget);
      final levels = await _levelService.fetchLevels();
      final allImagePaths = levels
          .where((level) => level.imagePath != null)
          .map((level) => level.imagePath!)
          .toList();
      final initialImagePaths = allImagePaths.take(_initialPreloadCount).toList();
      final remainingImagePaths = allImagePaths.skip(_initialPreloadCount).toList();

      if (!mounted) return;

      setState(() {
        _progress = 0;
        _targetProgress = _warmupTarget;
        _error = null;
      });

      await _storageService.preloadImages(
        initialImagePaths,
        onProgress: (completed, total) {
          if (!mounted) return;
          final actualProgress = total == 0 ? 0.0 : completed / total;
          _setProgressTarget(actualProgress < _warmupTarget ? _warmupTarget : actualProgress);
        },
      );

      if (!mounted) return;

      _setProgressTarget(1);
      while (mounted && _progress < 0.985) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }

      if (!mounted) return;
      final navigator = Navigator.of(context);

      unawaited(
        _storageService.preloadImages(remainingImagePaths).catchError((_) {}),
      );
      unawaited(
        TelemetryService.instance.logLoadingFinished(
          initialImagesPreloaded: initialImagePaths.length,
        ),
      );

      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const GameScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _targetProgress = 0;
        _error = 'Failed to download images';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).round().clamp(0, 100);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5DE),
              Color(0xFFFFE7BE),
              Color(0xFFF2BC74),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _error == null ? _progress : null,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFF6E4BF),
                        color: const Color(0xFF7C4D17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error == null ? '$percent%' : 'Could not load',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B491E),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () async {
                        await FeedbackService.instance.tap();
                        _preloadImages();
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
