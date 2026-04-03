import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  static const _soundEnabledKey = 'sound_enabled';
  static const _vibrationEnabledKey = 'vibration_enabled';
  static const _tapSound = 'tap.mp3';
  static const _successSound = 'success.mp3';
  static const _failSound = 'fail.mp3';
  static const _powerupSound = 'powerup.mp3';

  final Map<String, AudioPlayer> _playersByFile = <String, AudioPlayer>{};
  final Set<String> _preloadedFiles = <String>{};

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
    unawaited(_warmUpPlayers());
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, value);
  }

  Future<void> tap() async {
    if (_vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    unawaited(_play(_tapSound));
  }

  Future<void> success() async {
    if (_vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
    await _play(_successSound);
  }

  Future<void> fail() async {
    if (_vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    await _play(_failSound);
  }

  Future<void> powerup() async {
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    await _play(_powerupSound);
  }

  Future<void> _play(String fileName) async {
    if (!_soundEnabled) {
      return;
    }

    final player = _playersByFile.putIfAbsent(fileName, AudioPlayer.new);

    try {
      await player.stop();
      await player.play(
        AssetSource('sounds/$fileName'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Audio failures should never block game interactions.
    }
  }

  Future<void> _warmUpPlayers() async {
    if (!_soundEnabled) {
      return;
    }

    final sounds = <String>[_tapSound, _successSound, _failSound, _powerupSound];
    for (final fileName in sounds) {
      if (_preloadedFiles.contains(fileName)) {
        continue;
      }

      final player = _playersByFile.putIfAbsent(fileName, AudioPlayer.new);
      try {
        await player.setSource(AssetSource('sounds/$fileName'));
        _preloadedFiles.add(fileName);
      } catch (_) {
        // Best effort preload. Playback still attempts to play on demand.
      }
    }
  }
}
