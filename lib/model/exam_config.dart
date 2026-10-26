import 'dart:math';

import 'body_system.dart';

/// 'Luyện tập': no timer, an explanation after each answer.
/// 'Thi thử': a countdown per question and auto-advance.
enum ExamMode { practice, test }

/// Where an exam comes from, which decides how its result is saved.
enum ExamKind { custom, daily, mistakes }

enum QuestionType {
  /// The 3D "find X": tap the named part in the viewer.
  tapPart,

  /// The viewer highlights a part; pick its Vietnamese name from 4.
  namePart,

  /// An English term; pick the Vietnamese name from 4.
  enToVi,

  /// A Vietnamese term; pick the English name from 4.
  viToEn,
}

/// Route argument of [AppPage.exam].
class ExamConfig {
  const ExamConfig({
    this.system,
    this.length = 10,
    this.mode = ExamMode.practice,
    this.kind = ExamKind.custom,
    this.seed,
    this.partIds = const [],
    this.types = QuestionType.values,
  });

  /// Today's challenge; the controller seeds it with `ProgressService.dailySeed`.
  const ExamConfig.daily({this.seed})
    : system = null,
      length = dailyLength,
      mode = ExamMode.test,
      kind = ExamKind.daily,
      partIds = const [],
      types = QuestionType.values;

  /// Review of the mistake book: 3D questions only, with explanations.
  factory ExamConfig.mistakes(List<String> partIds) => ExamConfig(
    length: min(partIds.length, maxReviewLength),
    kind: ExamKind.mistakes,
    partIds: partIds,
    types: const [QuestionType.tapPart, QuestionType.namePart],
  );

  /// Scope; null means the whole body ('Toàn thân').
  final BodySystem? system;
  final int length;
  final ExamMode mode;
  final ExamKind kind;

  /// Same seed, same questions (the daily challenge). Null: a fresh exam.
  final int? seed;

  /// When set, questions are asked only about these parts.
  final List<String> partIds;
  final List<QuestionType> types;

  static const lengths = [10, 20, 40];
  static const dailyLength = 10;
  static const maxReviewLength = 20;
  static const secondsPerQuestion = 20;
  static const wholeBodyId = 'all';

  bool get timed => mode == ExamMode.test;

  Duration? get timeLimit => timed ? const Duration(seconds: secondsPerQuestion) : null;

  /// Key of the best score of this scope, see `ProgressService.examBest`.
  String get scopeId => system?.name ?? wholeBodyId;

  ExamConfig copyWith({int? seed, List<String>? partIds, int? length}) => ExamConfig(
    system: system,
    length: length ?? this.length,
    mode: mode,
    kind: kind,
    seed: seed ?? this.seed,
    partIds: partIds ?? this.partIds,
    types: types,
  );
}
