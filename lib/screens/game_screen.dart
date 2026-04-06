import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/level_model.dart';
import '../services/ad_service.dart';
import '../services/feedback_service.dart';
import '../services/level_service.dart';
import '../services/progress_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/app_banner_ad.dart';
import '../widgets/level_image.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final LevelService _levelService = LevelService();
  final ProgressService _progressService = ProgressService();
  final Random _random = Random();
  final GlobalKey _overlayKey = GlobalKey();
  final GlobalKey _imageCardKey = GlobalKey();
  final GlobalKey _imageFocusKey = GlobalKey();
  final GlobalKey _scrambleCardKey = GlobalKey();
  final GlobalKey _scrambleWordKey = GlobalKey();
  final GlobalKey _answerRowKey = GlobalKey();
  final GlobalKey _actionRowKey = GlobalKey();
  final GlobalKey _lettersKey = GlobalKey();

  List<LevelModel> _levels = [];
  LevelModel? _currentLevel;
  int _currentLevelNumber = 1;
  bool _isLoading = true;
  bool _isChecking = false;
  String? _message;
  bool? _lastAnswerCorrect;
  int _lastInterstitialCheckpoint = 0;
  String? _revealedHint;
  String _scrambledClue = '';
  bool _isTutorialPending = false;
  _TutorialType? _activeTutorial;
  int _tutorialStepIndex = 0;
  int? _tutorialReplayReturnLevelId;
  bool _isImageReadyForTutorial = false;
  late final AnimationController _tutorialPulseController;

  List<_LetterTileData> _letterTiles = [];
  List<_SelectedLetter?> _answerSlots = [];

  @override
  void initState() {
    super.initState();
    _tutorialPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _loadGame();
  }

  @override
  void dispose() {
    _tutorialPulseController.dispose();
    super.dispose();
  }

  String _normalizeAnswer(String input) {
    return input.toLowerCase().trim().replaceAll(RegExp(r'[_\-\s]'), '');
  }

  Future<void> _loadGame() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final levels = await _levelService.fetchLevels();
      final savedLevel = await _progressService.getCurrentLevel();

      if (!mounted) return;

      final current = levels.firstWhere(
        (level) => level.id == savedLevel,
        orElse: () => levels.first,
      );
      final shouldHoldForTutorial = await _shouldHoldForTutorial(current);

      setState(() {
        _levels = levels;
        _currentLevel = current;
        _currentLevelNumber = current.id;
        _prepareLevel(current);
        _isTutorialPending = shouldHoldForTutorial;
        _isLoading = false;
      });
      unawaited(
        TelemetryService.instance.logLevelStarted(
          level: current.id,
          isScramble: current.isScramble,
          fromReplay: false,
        ),
      );
      _scheduleTutorialCheck(current);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message = e.toString();
      });
    }
  }

  void _prepareLevel(LevelModel level) {
    final answerLetters = _normalizeAnswer(level.answer).split('');
    final allLetters = level.isScramble
        ? ([...answerLetters.map((letter) => letter.toUpperCase())]..sort())
        : _buildStandardLetterBank(answerLetters);

    _answerSlots = List<_SelectedLetter?>.filled(answerLetters.length, null);
    _letterTiles = [
      for (var i = 0; i < allLetters.length; i++)
        _LetterTileData(id: '$i-${allLetters[i]}', letter: allLetters[i]),
    ];
    _scrambledClue = _buildScrambledClue(answerLetters);
    _message = null;
    _lastAnswerCorrect = null;
    _revealedHint = null;
    _isImageReadyForTutorial = level.isScramble;
  }

  void _handleLevelImageReady() {
    if (!mounted || _isImageReadyForTutorial) return;
    setState(() {
      _isImageReadyForTutorial = true;
    });
  }

  List<String> _buildStandardLetterBank(List<String> answerLetters) {
    final extraCount = max(18 - answerLetters.length, 0);
    final extraLetters = List<String>.generate(
      extraCount,
      (_) => String.fromCharCode(65 + _random.nextInt(26)),
    );

    return [
      ...answerLetters.map((letter) => letter.toUpperCase()),
      ...extraLetters,
    ]..shuffle(_random);
  }

  String _buildScrambledClue(List<String> answerLetters) {
    if (answerLetters.length < 2) {
      return answerLetters.join().toUpperCase();
    }

    final letters = [...answerLetters.map((letter) => letter.toUpperCase())];
    var shuffled = [...letters];

    do {
      shuffled.shuffle(_random);
    } while (listEquals(shuffled, letters));

    return shuffled.join(' ');
  }

  String get _currentGuess => _answerSlots
      .whereType<_SelectedLetter>()
      .map((slot) => slot.letter)
      .join();

  bool get _isAnswerComplete => _answerSlots.every((slot) => slot != null);

  String get _currentAnswer => _normalizeAnswer(_currentLevel?.answer ?? '');

  bool get _isScrambleChallengeLevel => _currentLevel?.isScramble ?? false;

  bool get _isGuidedImageSolveStep =>
      _activeTutorial == _TutorialType.image &&
      _tutorialStepIndex == 5 &&
      _currentLevel?.id == 1;

  bool get _isGuidedScrambleSolveStep =>
      _activeTutorial == _TutorialType.scramble &&
      _tutorialStepIndex == 4 &&
      _currentLevel?.isScramble == true &&
      _currentLevel?.id == 3;

  _LetterTileData? get _guidedTutorialTile {
    if ((!_isGuidedImageSolveStep && !_isGuidedScrambleSolveStep) ||
        _currentLevel == null) {
      return null;
    }

    final nextSlotIndex = _answerSlots.indexOf(null);
    if (nextSlotIndex == -1) {
      return null;
    }

    final targetLetter = _currentAnswer[nextSlotIndex].toUpperCase();
    for (final tile in _letterTiles) {
      if (!tile.isUsed && !tile.isRemoved && tile.letter == targetLetter) {
        return tile;
      }
    }

    return null;
  }

  void _selectLetter(_LetterTileData tile) {
    if (_isChecking || tile.isUsed || tile.isRemoved) return;
    if ((_isGuidedImageSolveStep || _isGuidedScrambleSolveStep) &&
        _guidedTutorialTile?.id != tile.id) {
      return;
    }

    final emptyIndex = _answerSlots.indexOf(null);
    if (emptyIndex == -1) return;

    unawaited(FeedbackService.instance.tap());

    setState(() {
      _answerSlots[emptyIndex] = _SelectedLetter(
        tileId: tile.id,
        letter: tile.letter,
      );
      tile.isUsed = true;
      _message = null;
      _lastAnswerCorrect = null;
    });

    if (_isAnswerComplete) {
      if (_isGuidedImageSolveStep || _isGuidedScrambleSolveStep) {
        unawaited(_completeGuidedTutorialSolve());
      } else {
        unawaited(_submitAnswer());
      }
    }
  }

  void _removeLetterAt(int index) {
    if (_isChecking) return;

    final selected = _answerSlots[index];
    if (selected == null) return;

    unawaited(FeedbackService.instance.tap());

    final tileIndex = _letterTiles.indexWhere(
      (tile) => tile.id == selected.tileId,
    );

    setState(() {
      _answerSlots[index] = null;
      if (tileIndex != -1) {
        _letterTiles[tileIndex].isUsed = false;
      }
      _message = null;
      _lastAnswerCorrect = null;
    });
  }

  void _undoLastLetter() {
    if (_isChecking) return;

    final lastFilledIndex = _answerSlots.lastIndexWhere((slot) => slot != null);
    if (lastFilledIndex == -1) return;

    _removeLetterAt(lastFilledIndex);
  }

  void _removeWrongLetters() {
    if (_isChecking || _currentLevel == null) return;

    final answerCounts = <String, int>{};
    for (final letter in _currentAnswer.split('')) {
      answerCounts.update(
        letter.toUpperCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final remainingAnswerCounts = Map<String, int>.from(answerCounts);
    final removableTiles = <_LetterTileData>[];

    for (final tile in _letterTiles.where(
      (tile) => !tile.isUsed && !tile.isRemoved,
    )) {
      final remaining = remainingAnswerCounts[tile.letter] ?? 0;
      if (remaining > 0) {
        remainingAnswerCounts[tile.letter] = remaining - 1;
      } else {
        removableTiles.add(tile);
      }
    }

    if (removableTiles.isEmpty) {
      return;
    }

    final removeCount = removableTiles.length;

    setState(() {
      for (final tile in removableTiles) {
        tile.isRemoved = true;
      }
      _message = 'removed:$removeCount';
      _lastAnswerCorrect = null;
    });
    unawaited(
      TelemetryService.instance.logHelperUsed(
        helper: 'simplify',
        level: _currentLevel!.id,
        isScramble: _currentLevel!.isScramble,
      ),
    );
  }

  Future<void> _useRewardedAction({
    required VoidCallback onRewarded,
    required String actionName,
  }) async {
    final didEarnReward = await AdService.instance.showRewardedAd(
      onRewarded: () {
        unawaited(FeedbackService.instance.powerup());
        onRewarded();
      },
    );

    if (!mounted || didEarnReward) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName ad is not ready yet. Please try again.'),
      ),
    );
  }

  void _revealRandomLetter() {
    if (_isChecking || _currentLevel == null) return;

    final emptyIndexes = <int>[];
    for (var i = 0; i < _answerSlots.length; i++) {
      if (_answerSlots[i] == null) {
        emptyIndexes.add(i);
      }
    }

    if (emptyIndexes.isEmpty) {
      return;
    }

    emptyIndexes.shuffle(_random);
    final targetIndex = emptyIndexes.first;
    final targetLetter = _currentAnswer[targetIndex].toUpperCase();

    _LetterTileData? matchingTile;
    for (final tile in _letterTiles) {
      if (!tile.isUsed && !tile.isRemoved && tile.letter == targetLetter) {
        matchingTile = tile;
        break;
      }
    }

    if (matchingTile == null) {
      setState(() {
        _message = 'no_letter';
        _lastAnswerCorrect = null;
      });
      return;
    }

    setState(() {
      _answerSlots[targetIndex] = _SelectedLetter(
        tileId: matchingTile!.id,
        letter: matchingTile.letter,
      );
      matchingTile.isUsed = true;
      _message = null;
      _lastAnswerCorrect = null;
    });
    unawaited(
      TelemetryService.instance.logHelperUsed(
        helper: 'reveal',
        level: _currentLevel!.id,
        isScramble: _currentLevel!.isScramble,
      ),
    );

    if (_isAnswerComplete) {
      unawaited(_submitAnswer());
    }
  }

  Future<void> _submitAnswer() async {
    final level = _currentLevel;
    if (level == null || !_isAnswerComplete || _isChecking) return;

    setState(() {
      _isChecking = true;
    });

    final isCorrect =
        _normalizeAnswer(_currentGuess) == _normalizeAnswer(level.answer);

    if (isCorrect) {
      unawaited(
        TelemetryService.instance.logLevelCompleted(
          level: level.id,
          isScramble: level.isScramble,
        ),
      );
      await FeedbackService.instance.success();
      setState(() {
        _message = 'correct';
        _lastAnswerCorrect = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 850));
      await _goToNextLevel();
      return;
    }

    await FeedbackService.instance.fail();
    unawaited(
      TelemetryService.instance.logLevelFailed(
        level: level.id,
        isScramble: level.isScramble,
      ),
    );
    setState(() {
      _message = 'try_again';
      _lastAnswerCorrect = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isChecking = false;
      for (final tile in _letterTiles) {
        tile.isUsed = false;
        tile.isRemoved = false;
      }
      _answerSlots = List<_SelectedLetter?>.filled(_answerSlots.length, null);
      _message = null;
      _lastAnswerCorrect = null;
    });
  }

  Future<void> _goToNextLevel() async {
    if (_levels.isEmpty || _currentLevel == null) return;

    final currentIndex = _levels.indexWhere(
      (level) => level.id == _currentLevel!.id,
    );
    final hasNext = currentIndex >= 0 && currentIndex < _levels.length - 1;

    if (!hasNext) {
      if (!mounted) return;
      setState(() {
        _message = 'finished';
        _lastAnswerCorrect = true;
        _isChecking = false;
      });
      return;
    }

    final nextLevel = _levels[currentIndex + 1];
    final completedLevel = _currentLevel!.id;
    await _progressService.saveCurrentLevel(nextLevel.id);
    final shouldHoldForTutorial = await _shouldHoldForTutorial(nextLevel);

    if (completedLevel % 5 == 0 &&
        _lastInterstitialCheckpoint != completedLevel) {
      _lastInterstitialCheckpoint = completedLevel;
      await AdService.instance.showInterstitialIfAvailable();
    }

    if (!mounted) return;

    setState(() {
      _currentLevel = nextLevel;
      _currentLevelNumber = nextLevel.id;
      _prepareLevel(nextLevel);
      _isTutorialPending = shouldHoldForTutorial;
      _isChecking = false;
    });
    unawaited(
      TelemetryService.instance.logLevelStarted(
        level: nextLevel.id,
        isScramble: nextLevel.isScramble,
        fromReplay: false,
      ),
    );
    _scheduleTutorialCheck(nextLevel);
  }

  Future<bool> _shouldHoldForTutorial(LevelModel level) async {
    if (level.isScramble) {
      if (level.id != 3) return false;
      return !(await _progressService.hasSeenScrambleTutorial());
    }

    if (level.id != 1) return false;
    return !(await _progressService.hasSeenImageTutorial());
  }

  void _scheduleTutorialCheck(LevelModel level) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentLevel?.id != level.id) return;
      unawaited(() async {
        await Future<void>.delayed(
          level.isScramble
              ? const Duration(milliseconds: 180)
              : const Duration(milliseconds: 420),
        );
        if (!mounted || _currentLevel?.id != level.id) return;
        await _maybeShowTutorial(level);
      }());
    });
  }

  void _refreshTutorialOverlayFrames([int remaining = 3]) {
    if (remaining <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeTutorial == null) return;
      setState(() {});
      _refreshTutorialOverlayFrames(remaining - 1);
    });
  }

  Future<void> _maybeShowTutorial(LevelModel level) async {
    if (_activeTutorial != null) return;

    if (level.isScramble) {
      final isTargetReady = await _waitForTargetRect(_scrambleCardKey);
      if (!mounted || _currentLevel?.id != level.id || !isTargetReady) return;

      final hasSeenScrambleTutorial = await _progressService
          .hasSeenScrambleTutorial();
      if (!mounted || _currentLevel?.id != level.id) return;
      if (hasSeenScrambleTutorial) {
        setState(() {
          _isTutorialPending = false;
        });
        return;
      }

      setState(() {
        _activeTutorial = _TutorialType.scramble;
        _tutorialStepIndex = 0;
        _isTutorialPending = false;
      });
      _refreshTutorialOverlayFrames();
      return;
    }

    if (!_isImageReadyForTutorial) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted ||
          _currentLevel?.id != level.id ||
          !_isImageReadyForTutorial) {
        _scheduleTutorialCheck(level);
        return;
      }
    }

    final isTargetReady = await _waitForTargetRect(_imageFocusKey);
    if (!mounted || _currentLevel?.id != level.id || !isTargetReady) return;

    final hasSeenImageTutorial = await _progressService.hasSeenImageTutorial();
    if (!mounted || _currentLevel?.id != level.id) return;
    if (hasSeenImageTutorial) {
      setState(() {
        _isTutorialPending = false;
      });
      return;
    }

    setState(() {
      _activeTutorial = _TutorialType.image;
      _tutorialStepIndex = 0;
      _isTutorialPending = false;
    });
    _refreshTutorialOverlayFrames();
  }

  List<_TutorialStep> get _tutorialSteps {
    switch (_activeTutorial) {
      case _TutorialType.image:
        return [
          _TutorialStep(
            title: 'Look at the picture',
            body:
                'This picture is your clue. Here it shows a fork being lifted by a person, which points you toward the answer.',
            targetKey: _imageFocusKey,
            panelAlignment: Alignment.bottomCenter,
          ),
          _TutorialStep(
            title: 'Build the answer here',
            body: 'Tap letters below to fill these boxes in the right order.',
            targetKey: _answerRowKey,
            panelAlignment: Alignment.center,
          ),
          _TutorialStep(
            title: 'Use the letter tiles',
            body:
                'Pick letters from here. If you get stuck, the helper buttons can help.',
            targetKey: _lettersKey,
            panelAlignment: Alignment.center,
          ),
          _TutorialStep(
            title: 'Need help?',
            body:
                'Undo removes your last step, Simplify removes excluded letters to make the word easier to find, Reveal shows a random letter, and Hint displays a text clue to help with the solution.',
            targetKey: _actionRowKey,
            panelAlignment: Alignment.bottomCenter,
          ),
          _TutorialStep(
            title: 'We will solve it together',
            body:
                'Now follow the glowing letter. I will guide you through the whole first word.',
            targetKey: _answerRowKey,
            panelAlignment: Alignment.center,
          ),
          _TutorialStep(
            title: 'Your turn',
            body:
                'Tap the glowing letter to build the answer one step at a time.',
            targetKey: _lettersKey,
            panelAlignment: Alignment.topCenter,
          ),
        ];
      case _TutorialType.scramble:
        return [
          _TutorialStep(
            title: 'Read the scrambled clue',
            body:
                'These mixed letters hint at the hidden word you need to solve.',
            targetKey: _scrambleCardKey,
            panelAlignment: Alignment.bottomCenter,
          ),
          _TutorialStep(
            title: 'Build the real word',
            body:
                'Use the answer slots to place the letters in the correct order.',
            targetKey: _answerRowKey,
            panelAlignment: Alignment.bottomCenter,
          ),
          _TutorialStep(
            title: 'Need help?',
            body:
                'Undo removes your last step, Reveal shows a random letter, and Hint displays a text clue to help with the solution.',
            targetKey: _actionRowKey,
            panelAlignment: Alignment.bottomCenter,
          ),
          _TutorialStep(
            title: 'We will solve this one together',
            body:
                'Follow the glowing letter and we will finish the first scrambled word together.',
            targetKey: _answerRowKey,
            panelAlignment: Alignment.center,
          ),
          _TutorialStep(
            title: 'Your turn',
            body:
                'Tap the glowing letter to build the scrambled answer one step at a time.',
            targetKey: _lettersKey,
            panelAlignment: Alignment.topCenter,
          ),
        ];
      case null:
        return const [];
    }
  }

  Rect? _rectForKey(GlobalKey key) {
    final overlayContext = _overlayKey.currentContext;
    final targetContext = key.currentContext;
    if (overlayContext == null || targetContext == null) return null;

    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || targetBox == null) return null;

    final offset = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return offset & targetBox.size;
  }

  Future<bool> _waitForTargetRect(
    GlobalKey key, {
    int attempts = 8,
    Duration delay = const Duration(milliseconds: 90),
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (!mounted) return false;
      final rect = _rectForKey(key);
      if (rect != null && rect.width > 0 && rect.height > 0) {
        return true;
      }
      await Future<void>.delayed(delay);
    }
    return false;
  }

  Rect? _tutorialHighlightRect(_TutorialStep step, Rect? rect) {
    if (rect == null) return null;
    if (step.title == 'We will solve it together') return null;
    if (step.title == 'We will solve this one together') return null;
    if (step.title == 'Look at the picture') {
      return Rect.fromLTWH(
        rect.left - 3,
        rect.top - 8,
        rect.width + 6,
        rect.height + 6,
      );
    }
    if (step.title == 'Build the answer here') return rect.inflate(8);
    if (step.title == 'Use the letter tiles') return rect.inflate(6);
    if (step.title == 'Read the scrambled clue') return rect.inflate(4);
    if (step.title == 'Build the real word') return rect.inflate(8);
    if (step.title == 'Need help?') return rect.inflate(8);
    return rect.inflate(12);
  }

  double? _tutorialPanelTop(_TutorialStep step, Rect? highlightRect) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (step.title == 'We will solve it together') {
      return screenHeight * 0.34;
    }
    if (step.title == 'We will solve this one together') {
      return screenHeight * 0.34;
    }
    if (highlightRect == null) return null;
    if (step.title == 'Look at the picture') {
      return min(highlightRect.bottom + 10, screenHeight - 220);
    }
    if (step.title == 'Read the scrambled clue') {
      return min(highlightRect.bottom + 10, screenHeight - 220);
    }
    if (step.title == 'Build the answer here') {
      return min(highlightRect.bottom + 16, screenHeight - 220);
    }
    if (step.title == 'Build the real word') {
      return min(highlightRect.bottom + 10, screenHeight - 220);
    }
    if (step.title == 'Use the letter tiles') {
      return max(24.0, highlightRect.top - 196);
    }
    if (step.title == 'Need help?') {
      return null;
    }
    return max(24.0, highlightRect.top - 132);
  }

  double? _tutorialPanelBottom(_TutorialStep step, Rect? highlightRect) {
    if (highlightRect == null) return null;
    if (step.title == 'Need help?') {
      return max(
        24.0,
        MediaQuery.of(context).size.height - highlightRect.top + 18,
      );
    }
    return null;
  }

  Future<void> _advanceTutorial() async {
    final steps = _tutorialSteps;
    if (_tutorialStepIndex >= steps.length - 1) {
      if (_isGuidedImageSolveStep || _isGuidedScrambleSolveStep) {
        return;
      }
      await _dismissTutorial();
      return;
    }

    setState(() {
      _tutorialStepIndex += 1;
    });
    _refreshTutorialOverlayFrames();
  }

  Future<void> _startTutorialReplay(_TutorialType type) async {
    final current = _currentLevel;
    if (current == null) return;

    final targetLevel = _levels.firstWhere(
      (level) =>
          type == _TutorialType.image ? !level.isScramble : level.isScramble,
      orElse: () => current,
    );

    setState(() {
      _tutorialReplayReturnLevelId = current.id == targetLevel.id
          ? null
          : current.id;
      _currentLevel = targetLevel;
      _currentLevelNumber = targetLevel.id;
      _prepareLevel(targetLevel);
      _isChecking = false;
      _activeTutorial = type;
      _tutorialStepIndex = 0;
    });
    unawaited(
      TelemetryService.instance.logTutorialReplay(
        tutorialType: type == _TutorialType.image ? 'image' : 'scramble',
      ),
    );
    unawaited(
      TelemetryService.instance.logLevelStarted(
        level: targetLevel.id,
        isScramble: targetLevel.isScramble,
        fromReplay: true,
      ),
    );
    _refreshTutorialOverlayFrames();
  }

  Future<void> _dismissTutorial() async {
    final tutorial = _activeTutorial;
    if (tutorial == null) return;

    setState(() {
      _activeTutorial = null;
      _tutorialStepIndex = 0;
    });

    if (tutorial == _TutorialType.image) {
      await _progressService.markImageTutorialSeen();
    } else {
      await _progressService.markScrambleTutorialSeen();
    }

    await _restoreTutorialReplayLevelIfNeeded();
  }

  Future<void> _exitTutorialReplay() async {
    if (_tutorialReplayReturnLevelId == null) {
      return;
    }

    await _dismissTutorial();
  }

  Future<void> _completeGuidedTutorialSolve() async {
    if (_tutorialReplayReturnLevelId != null) {
      await FeedbackService.instance.success();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _dismissTutorial();
      return;
    }

    final tutorial = _activeTutorial;
    if (tutorial == null) return;

    setState(() {
      _activeTutorial = null;
      _tutorialStepIndex = 0;
    });

    if (tutorial == _TutorialType.image) {
      await _progressService.markImageTutorialSeen();
    } else {
      await _progressService.markScrambleTutorialSeen();
    }

    if (!mounted) return;
    await FeedbackService.instance.success();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _goToNextLevel();
  }

  Future<void> _restoreTutorialReplayLevelIfNeeded() async {
    final returnLevelId = _tutorialReplayReturnLevelId;
    if (returnLevelId == null) {
      return;
    }

    final returnLevel = _levels.firstWhere(
      (level) => level.id == returnLevelId,
      orElse: () => _levels.first,
    );

    if (!mounted) return;

    setState(() {
      _tutorialReplayReturnLevelId = null;
      _currentLevel = returnLevel;
      _currentLevelNumber = returnLevel.id;
      _prepareLevel(returnLevel);
      _isChecking = false;
    });
  }

  void _showHint() {
    final level = _currentLevel;
    if (level == null) return;

    if (_revealedHint != null) {
      return;
    }

    setState(() {
      _revealedHint = level.hint;
    });
    unawaited(
      TelemetryService.instance.logHelperUsed(
        helper: 'hint',
        level: level.id,
        isScramble: level.isScramble,
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    unawaited(FeedbackService.instance.tap());
    unawaited(TelemetryService.instance.logSettingsOpened());
    if (!mounted) return;

    var soundEnabled = FeedbackService.instance.soundEnabled;
    var vibrationEnabled = FeedbackService.instance.vibrationEnabled;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFF7E7), Color(0xFFFFE1B0)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFF0C97F), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x227A4A00),
                      blurRadius: 26,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      size: 34,
                      color: Color(0xFF7C4D17),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Settings',
                      style: const TextStyle(
                        color: Color(0xFF4B3112),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSettingsToggleTile(
                      icon: Icons.volume_up_rounded,
                      label: 'Sound',
                      value: soundEnabled,
                      onChanged: (value) async {
                        await FeedbackService.instance.setSoundEnabled(value);
                        soundEnabled = value;
                        setModalState(() {});
                        if (value) {
                          unawaited(FeedbackService.instance.tap());
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsToggleTile(
                      icon: Icons.vibration_rounded,
                      label: 'Vibration',
                      value: vibrationEnabled,
                      onChanged: (value) async {
                        await FeedbackService.instance.setVibrationEnabled(
                          value,
                        );
                        vibrationEnabled = value;
                        setModalState(() {});
                        if (value) {
                          unawaited(FeedbackService.instance.tap());
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTutorialReplayButton(
                      icon: Icons.image_search_rounded,
                      label: 'Image Guess Tutorial',
                      onPressed: () {
                        Navigator.of(context).pop();
                        unawaited(_startTutorialReplay(_TutorialType.image));
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildTutorialReplayButton(
                      icon: Icons.shuffle_rounded,
                      label: 'Scrambled Word Tutorial',
                      onPressed: () {
                        Navigator.of(context).pop();
                        unawaited(_startTutorialReplay(_TutorialType.scramble));
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = _currentLevel;
    final tutorialStep = _activeTutorial == null
        ? null
        : _tutorialSteps[_tutorialStepIndex];
    final tutorialRect = tutorialStep == null
        ? null
        : (_isGuidedImageSolveStep || _isGuidedScrambleSolveStep)
        ? _rectForKey(_guidedTutorialTile?.key ?? tutorialStep.targetKey)
        : _rectForKey(tutorialStep.targetKey);
    final tutorialTitle =
        (_isGuidedImageSolveStep || _isGuidedScrambleSolveStep)
        ? 'Tap "${_guidedTutorialTile?.letter ?? ''}"'
        : tutorialStep?.title ?? '';
    final tutorialBody = (_isGuidedImageSolveStep || _isGuidedScrambleSolveStep)
        ? 'Press the glowing letter tile, then keep following the highlight until the word is complete.'
        : tutorialStep?.body ?? '';
    final shouldShowTutorialOverlay =
        tutorialStep != null &&
        !_isGuidedImageSolveStep &&
        !_isGuidedScrambleSolveStep;

    return Scaffold(
      bottomNavigationBar: _activeTutorial == null && !_isTutorialPending
          ? const AppBannerAd()
          : null,
      body: Stack(
        key: _overlayKey,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF5DE),
                  Color(0xFFFFE6BE),
                  Color(0xFFF8CB8C),
                ],
              ),
            ),
            child: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : level == null
                  ? Center(
                      child: Text(
                        _message != null
                            ? 'Failed to load levels: $_message'
                            : 'No levels available',
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final answerLength = _answerSlots.length;
                        final wordSpacing = width < 380 ? 7.0 : 10.0;
                        final wordSize = min(
                          width < 380 ? 28.0 : 32.0,
                          (width - 48 - (answerLength - 1) * wordSpacing) /
                              answerLength,
                        );
                        final tileSpacing = width < 380 ? 6.0 : 8.0;
                        final tileSize = width < 380 ? 40.0 : 44.0;

                        return Opacity(
                          opacity: _isTutorialPending && _activeTutorial == null
                              ? 0
                              : 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Column(
                              children: [
                                _buildTopBar(),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 10,
                                        child: Center(
                                          child: _isScrambleChallengeLevel
                                              ? _buildScrambleChallengeCard(
                                                  width,
                                                )
                                              : _buildImageCard(level, width),
                                        ),
                                      ),
                                      if (_revealedHint != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF6B491E),
                                              width: 1.4,
                                            ),
                                          ),
                                          child: Text(
                                            'Hint: $_revealedHint',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF6B491E),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        key: _answerRowKey,
                                        height: wordSize + 10,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            for (
                                              var i = 0;
                                              i < _answerSlots.length;
                                              i++
                                            ) ...[
                                              _buildAnswerSlot(i, wordSize),
                                              if (i != _answerSlots.length - 1)
                                                SizedBox(width: wordSpacing),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildActionRow(),
                                      const SizedBox(height: 14),
                                      Expanded(
                                        flex: 6,
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Wrap(
                                            key: _lettersKey,
                                            alignment: WrapAlignment.center,
                                            spacing: tileSpacing,
                                            runSpacing: tileSpacing,
                                            children: _letterTiles
                                                .map(
                                                  (tile) => _buildLetterTile(
                                                    tile,
                                                    tileSize,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (shouldShowTutorialOverlay)
            _buildTutorialOverlay(
              tutorialStep,
              tutorialRect,
              title: tutorialTitle,
              body: tutorialBody,
            ),
          if (_tutorialReplayReturnLevelId != null)
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: TextButton.icon(
                  onPressed: _exitTutorialReplay,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5A3B14),
                    backgroundColor: const Color(0xFFFDF4E2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(
                        color: Color(0xFFF0C97F),
                        width: 1.6,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(
                    'Exit Tutorial',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const SizedBox(width: 48),
        Expanded(
          child: Text(
            'Level $_currentLevelNumber',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: _activeTutorial == null ? _showSettingsDialog : null,
              icon: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF5A3B14),
              ),
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard(LevelModel level, double width) {
    return ConstrainedBox(
      key: _imageCardKey,
      constraints: BoxConstraints(maxWidth: min(width - 24, 320)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A7A4A00),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0D39A), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              key: _imageFocusKey,
              borderRadius: BorderRadius.circular(20),
              child: LevelImage(
                imagePath: level.imagePath!,
                onImageReady: _handleLevelImageReady,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrambleChallengeCard(double width) {
    return ConstrainedBox(
      key: _scrambleCardKey,
      constraints: BoxConstraints(maxWidth: min(width - 24, 320)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A7A4A00),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF0D39A), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF8E8), Color(0xFFFFE4B5)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shuffle_rounded,
                size: 34,
                color: Color(0xFF7C4D17),
              ),
              const SizedBox(height: 12),
              Text(
                'Scrambled Word',
                style: const TextStyle(
                  color: Color(0xFF5A3B14),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                key: _scrambleWordKey,
                height: 36,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _scrambledClue,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerSlot(int index, double size) {
    final selected = _answerSlots[index];
    final background = _lastAnswerCorrect == true
        ? const Color(0xFFCBEED7)
        : _lastAnswerCorrect == false
        ? const Color(0xFFF5C0B4)
        : const Color(0xFFFFF9EE);

    return GestureDetector(
      onTap: () => _removeLetterAt(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size + 8,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected == null
                ? const Color(0xFFE6C88E)
                : const Color(0xFF916126),
            width: 1.8,
          ),
        ),
        child: Center(
          child: Text(
            selected?.letter ?? '',
            style: TextStyle(
              fontSize: size * 0.48,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      key: _actionRowKey,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          onPressed: _undoLastLetter,
          icon: Icons.undo_rounded,
          label: 'Undo',
        ),
        if (!_isScrambleChallengeLevel) ...[
          const SizedBox(width: 10),
          _buildActionButton(
            onPressed: () => _useRewardedAction(
              onRewarded: _removeWrongLetters,
              actionName: 'Simplify',
            ),
            icon: Icons.remove_circle_outline_rounded,
            label: 'Simplify',
            showsAdBadge: true,
          ),
        ],
        const SizedBox(width: 10),
        _buildActionButton(
          onPressed: () => _useRewardedAction(
            onRewarded: _revealRandomLetter,
            actionName: 'Reveal',
          ),
          icon: Icons.visibility_outlined,
          label: 'Reveal',
          showsAdBadge: true,
        ),
        const SizedBox(width: 10),
        _buildActionButton(
          onPressed: () =>
              _useRewardedAction(onRewarded: _showHint, actionName: 'Hint'),
          icon: Icons.lightbulb_outline_rounded,
          label: 'Hint',
          showsAdBadge: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool showsAdBadge = false,
  }) {
    final isDisabledByTutorial = _activeTutorial != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 72,
          child: OutlinedButton(
            onPressed: isDisabledByTutorial
                ? null
                : () {
                    unawaited(FeedbackService.instance.tap());
                    onPressed();
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showsAdBadge)
          Positioned(
            top: -2,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4D17),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Ad',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTutorialOverlay(
    _TutorialStep step,
    Rect? rect, {
    required String title,
    required String body,
  }) {
    final highlightRect = _tutorialHighlightRect(step, rect);
    final panelTop = _tutorialPanelTop(step, highlightRect);
    final panelBottom = _tutorialPanelBottom(step, highlightRect);
    final panelAlignment = panelBottom != null && panelTop == null
        ? Alignment.bottomCenter
        : Alignment.topCenter;

    return Positioned.fill(
      child: Stack(
        children: [
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.transparent),
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _TutorialOverlayPainter(highlightRect),
            ),
          ),
          if (highlightRect != null)
            Positioned.fromRect(
              rect: highlightRect,
              child: IgnorePointer(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.03).animate(
                    CurvedAnimation(
                      parent: _tutorialPulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFFFD36D),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66FFD36D),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            top: panelTop,
            bottom: panelBottom,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Align(
                alignment: panelAlignment,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Container(
                    key: ValueKey('${step.title}$_tutorialStepIndex'),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF4E2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF0C97F),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x337A4A00),
                          blurRadius: 24,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF4B3112),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B491E),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _advanceTutorial,
                            child: Text(switch (step.title) {
                              'We will solve it together' => 'Let’s Solve',
                              _
                                  when _tutorialStepIndex ==
                                      _tutorialSteps.length - 1 =>
                                'Let’s Go',
                              _ => 'Got It',
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsToggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0D39A), width: 1.6),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C4D17)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4B3112),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF7C4D17),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialReplayButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLetterTile(_LetterTileData tile, double size) {
    final isGuidedStep = _isGuidedImageSolveStep || _isGuidedScrambleSolveStep;
    final isGuidedTarget = isGuidedStep && _guidedTutorialTile?.id == tile.id;
    final highlightOpacity = 0.45 + (_tutorialPulseController.value * 0.35);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: tile.isUsed || tile.isRemoved
          ? 0.18
          : (isGuidedStep && !isGuidedTarget)
          ? 0.26
          : 1,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _tutorialPulseController,
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: isGuidedTarget
                    ? [
                        BoxShadow(
                          color: Color.fromRGBO(
                            255,
                            211,
                            109,
                            highlightOpacity,
                          ),
                          blurRadius: 18,
                          spreadRadius: 1.5,
                        ),
                      ]
                    : const [],
              ),
              child: child,
            );
          },
          child: FilledButton(
            key: tile.key,
            onPressed:
                tile.isUsed ||
                    tile.isRemoved ||
                    (isGuidedStep && !isGuidedTarget)
                ? null
                : () => _selectLetter(tile),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: isGuidedTarget
                  ? const Color(0xFFB66A17)
                  : const Color(0xFF7C4D17),
              disabledBackgroundColor: const Color(0xFFE0C99E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              side: isGuidedTarget
                  ? const BorderSide(color: Color(0xFFFFD36D), width: 2.4)
                  : null,
              elevation: isGuidedTarget ? 8 : null,
              shadowColor: const Color(0x66FFD36D),
            ),
            child: Text(
              tile.letter,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterTileData {
  _LetterTileData({required this.id, required this.letter}) : key = GlobalKey();

  final String id;
  final String letter;
  final GlobalKey key;
  bool isUsed = false;
  bool isRemoved = false;
}

class _SelectedLetter {
  const _SelectedLetter({required this.tileId, required this.letter});

  final String tileId;
  final String letter;
}

enum _TutorialType { image, scramble }

class _TutorialStep {
  const _TutorialStep({
    required this.title,
    required this.body,
    required this.targetKey,
    required this.panelAlignment,
  });

  final String title;
  final String body;
  final GlobalKey targetKey;
  final Alignment panelAlignment;
}

class _TutorialOverlayPainter extends CustomPainter {
  const _TutorialOverlayPainter(this.highlightRect);

  final Rect? highlightRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0xC4000000);
    final fullPath = Path()..addRect(Offset.zero & size);
    final cutoutPath = Path();

    if (highlightRect != null) {
      cutoutPath.addRRect(
        RRect.fromRectAndRadius(highlightRect!, const Radius.circular(28)),
      );
    }

    final path = Path.combine(PathOperation.difference, fullPath, cutoutPath);

    canvas.drawPath(path, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _TutorialOverlayPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect;
  }
}
