enum LevelType {
  image,
  scramble,
}

class LevelModel {
  const LevelModel({
    required this.id,
    required this.answer,
    required this.hint,
    required this.type,
    this.imagePath,
  });

  final int id;
  final String answer;
  final String hint;
  final LevelType type;
  final String? imagePath;

  bool get isScramble => type == LevelType.scramble;

  factory LevelModel.fromImageJson(
    Map<String, dynamic> json, {
    required int id,
  }) {
    return LevelModel(
      id: id,
      imagePath: json['imagePath'] as String,
      answer: json['answer'] as String,
      hint: json['hint'] as String,
      type: LevelType.image,
    );
  }

  factory LevelModel.fromScrambleJson(
    Map<String, dynamic> json, {
    required int id,
  }) {
    return LevelModel(
      id: id,
      answer: json['answer'] as String,
      hint: json['hint'] as String,
      type: LevelType.scramble,
    );
  }
}
