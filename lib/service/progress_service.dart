import 'dart:math';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Player profile shared by every mode: XP and level, the daily streak, the
/// daily challenge, lesson stars and the book of missed parts. Call
/// `GetStorage.init()` before creating it.
class ProgressService extends GetxService {
  static const _keyXp = 'progress_xp';
  static const _keyStreak = 'progress_streak';
  static const _keyBestStreak = 'progress_best_streak';
  static const _keyLastActiveDay = 'progress_last_active_day';
  static const _keyDailyDay = 'progress_daily_day';
  static const _keyDailyScore = 'progress_daily_score';
  static const _keyMistakes = 'progress_mistakes';
  static const _keyLessonStarsPrefix = 'lesson_stars_';
  static const _keyExamBestPrefix = 'exam_best_';

  /// XP rewards, kept here so every mode pays the same.
  static const xpPerCorrect = 10;
  static const xpPerStar = 20;
  static const xpDailyBonus = 50;

  ProgressService({GetStorage? box, DateTime Function()? clock}) : _box = box ?? GetStorage(), _clock = clock ?? DateTime.now {
    xp = (_box.read<int>(_keyXp) ?? 0).obs;
    streak = _liveStreak().obs;
    mistakeCount = _mistakes.length.obs;
  }

  final GetStorage _box;
  final DateTime Function() _clock;

  late final RxInt xp;

  /// Days in a row with any activity; 0 once a whole day was missed.
  late final RxInt streak;

  /// Parts in the mistake book.
  late final RxInt mistakeCount;

  int get bestStreak => _box.read<int>(_keyBestStreak) ?? 0;

  /// Level from total XP: level n needs 50·n·(n−1) XP (0, 100, 300, 600…).
  static int levelFor(int xp) => ((1 + sqrt(1 + 8 * xp / 100)) / 2).floor();

  static int xpForLevel(int level) => 50 * level * (level - 1);

  int get level => levelFor(xp.value);

  /// Progress (0–1) from the current level to the next.
  double get levelProgress {
    final from = xpForLevel(level);
    final to = xpForLevel(level + 1);
    return (xp.value - from) / (to - from);
  }

  int get xpToNextLevel => xpForLevel(level + 1) - xp.value;

  /// Adds [amount] XP and counts today towards the streak; returns whether
  /// the player levelled up.
  Future<bool> addXp(int amount) async {
    final before = level;
    xp.value += max(0, amount);
    await _box.write(_keyXp, xp.value);
    await recordActivity();
    return level > before;
  }

  /// Marks today as active, extending or restarting the streak.
  Future<void> recordActivity() async {
    final today = _day(_clock());
    final last = _box.read<String>(_keyLastActiveDay);
    if (last == today) return;
    final yesterday = _day(_clock().subtract(const Duration(days: 1)));
    final next = last == yesterday ? (_box.read<int>(_keyStreak) ?? 0) + 1 : 1;
    await _box.write(_keyStreak, next);
    await _box.write(_keyLastActiveDay, today);
    if (next > bestStreak) await _box.write(_keyBestStreak, next);
    streak.value = next;
  }

  int _liveStreak() {
    final last = _box.read<String>(_keyLastActiveDay);
    final today = _day(_clock());
    final yesterday = _day(_clock().subtract(const Duration(days: 1)));
    return last == today || last == yesterday ? _box.read<int>(_keyStreak) ?? 0 : 0;
  }

  /// Today's date as yyyy-mm-dd; also the daily challenge seed.
  String get today => _day(_clock());

  static String _day(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Same seed for every player on the same day.
  int get dailySeed => today.hashCode & 0x7fffffff;

  bool get dailyDone => _box.read<String>(_keyDailyDay) == today;

  /// Today's daily challenge score, null when not played yet.
  int? get dailyScore => dailyDone ? _box.read<int>(_keyDailyScore) : null;

  /// Saves the first daily result of the day; returns false if today's was
  /// already saved (replays don't pay again).
  Future<bool> saveDaily(int score) async {
    if (dailyDone) return false;
    await _box.write(_keyDailyDay, today);
    await _box.write(_keyDailyScore, score);
    return true;
  }

  int lessonStars(String lessonId) => _box.read<int>('$_keyLessonStarsPrefix$lessonId') ?? 0;

  /// Keeps the best stars of a lesson; returns whether they improved.
  Future<bool> saveLessonStars(String lessonId, int stars) async {
    if (stars <= lessonStars(lessonId)) return false;
    await _box.write('$_keyLessonStarsPrefix$lessonId', stars);
    return true;
  }

  int examBest(String examId) => _box.read<int>('$_keyExamBestPrefix$examId') ?? 0;

  /// Keeps the best exam score; returns whether it improved.
  Future<bool> saveExamScore(String examId, int score) async {
    if (score <= examBest(examId)) return false;
    await _box.write('$_keyExamBestPrefix$examId', score);
    return true;
  }

  /// Missed part ids with how many times each was missed, most missed first.
  List<MapEntry<String, int>> get mistakes {
    final list = _mistakes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  Map<String, int> get _mistakes => (_box.read<Map<String, dynamic>>(_keyMistakes) ?? const {}).cast<String, int>();

  Future<void> addMistake(String partId) async {
    final map = Map.of(_mistakes);
    map[partId] = (map[partId] ?? 0) + 1;
    await _box.write(_keyMistakes, map);
    mistakeCount.value = map.length;
  }

  /// A correct answer in review: one miss fewer, gone at zero.
  Future<void> resolveMistake(String partId) async {
    final map = Map.of(_mistakes);
    final left = (map[partId] ?? 0) - 1;
    if (left > 0) {
      map[partId] = left;
    } else {
      map.remove(partId);
    }
    await _box.write(_keyMistakes, map);
    mistakeCount.value = map.length;
  }
}
