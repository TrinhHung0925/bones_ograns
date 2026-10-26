import 'anatomy_part.dart';
import 'exam_config.dart';

/// What the exam result dialog shows.
class ExamResult {
  const ExamResult({
    required this.kind,
    required this.score,
    required this.correct,
    required this.total,
    required this.time,
    required this.xp,
    required this.missed,
    this.best,
    this.isNewBest = false,
    this.levelUp = false,
    this.streak,
    this.dailyFirst,
  });

  final ExamKind kind;
  final int score;
  final int correct;
  final int total;
  final Duration time;

  /// XP added to the profile (0 for a daily replay).
  final int xp;

  /// Targets of the wrong or missed questions.
  final List<AnatomyPart> missed;

  /// Best score of the scope (custom exams only).
  final int? best;
  final bool isNewBest;
  final bool levelUp;

  /// Daily challenge: the day streak, and whether this play paid the reward.
  final int? streak;
  final bool? dailyFirst;

  double get accuracy => total == 0 ? 0 : correct / total;
}
