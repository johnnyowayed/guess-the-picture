import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/level_model.dart';

class LevelService {
  Future<List<LevelModel>> fetchLevels() async {
    final imageLevels = await _loadImageLevels();
    final scrambleLevels = await _loadScrambleLevels();

    final mergedLevels = <LevelModel>[];
    var imageIndex = 0;
    var scrambleIndex = 0;
    var levelNumber = 1;

    while (imageIndex < imageLevels.length || scrambleIndex < scrambleLevels.length) {
      final shouldUseScramble =
          levelNumber % 3 == 0 &&
          scrambleIndex < scrambleLevels.length;

      if (shouldUseScramble) {
        final scramble = scrambleLevels[scrambleIndex++];
        mergedLevels.add(
          LevelModel.fromScrambleJson(
            {
              'answer': scramble.answer,
              'hint': scramble.hint,
            },
            id: levelNumber,
          ),
        );
      } else if (imageIndex < imageLevels.length) {
        final imageLevel = imageLevels[imageIndex++];
        mergedLevels.add(
          LevelModel.fromImageJson(
            {
              'imagePath': imageLevel.imagePath,
              'answer': imageLevel.answer,
              'hint': imageLevel.hint,
            },
            id: levelNumber,
          ),
        );
      } else {
        final scramble = scrambleLevels[scrambleIndex++];
        mergedLevels.add(
          LevelModel.fromScrambleJson(
            {
              'answer': scramble.answer,
              'hint': scramble.hint,
            },
            id: levelNumber,
          ),
        );
      }

      levelNumber += 1;
    }

    return mergedLevels;
  }

  Future<List<LevelModel>> _loadImageLevels() async {
    final jsonString = await rootBundle.loadString('assets/data/levels.json');
    final data = jsonDecode(jsonString) as List<dynamic>;

    return data
        .map(
          (item) => LevelModel.fromImageJson(
            item as Map<String, dynamic>,
            id: 0,
          ),
        )
        .toList();
  }

  Future<List<LevelModel>> _loadScrambleLevels() async {
    final jsonString = await rootBundle.loadString('assets/data/scramble_levels.json');
    final data = jsonDecode(jsonString) as List<dynamic>;

    return data
        .map(
          (item) => LevelModel.fromScrambleJson(
            item as Map<String, dynamic>,
            id: 0,
          ),
        )
        .toList();
  }
}
