/// Stars for a finished assembly: 3, minus one for 3+ wrong drops and minus
/// one for using any hint; never below 1.
int assemblyStars({required int mistakes, required int hints}) {
  var stars = 3;
  if (mistakes >= 3) stars--;
  if (hints > 0) stars--;
  return stars < 1 ? 1 : stars;
}

/// Points for each piece snapped into place.
const int assemblyPointsPerPiece = 100;

/// Points lost per wrong drop and per hint.
const int assemblyMistakePenalty = 30;
const int assemblyHintPenalty = 50;

/// Seconds per piece under which the time bonus is earned.
const int assemblyParSecondsPerPiece = 8;

/// Bonus for a combo of [count] pieces snapped in a row (none below 2).
int assemblyComboBonus(int count) => count < 2 ? 0 : 20 * (count - 1);

/// Bonus for finishing [pieces] pieces under par: 5 points per second saved.
int assemblyTimeBonus({required int pieces, required Duration time}) {
  final saved = pieces * assemblyParSecondsPerPiece - time.inSeconds;
  return saved > 0 ? saved * 5 : 0;
}

/// Score of a run: base points for placed pieces plus combo and time
/// bonuses, minus mistakes and hints; never negative.
int assemblyScore({required int placed, int comboBonus = 0, int timeBonus = 0, int mistakes = 0, int hints = 0}) {
  final score =
      placed * assemblyPointsPerPiece +
      comboBonus +
      timeBonus -
      mistakes * assemblyMistakePenalty -
      hints * assemblyHintPenalty;
  return score < 0 ? 0 : score;
}

/// "mm:ss" clock text; minutes keep counting past 59.
String formatClock(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final mm = (seconds ~/ 60).toString().padLeft(2, '0');
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}
