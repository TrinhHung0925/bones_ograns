import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../model/body_system.dart';
import '../model/graphics_quality.dart';

/// Small persistent preferences. Call `GetStorage.init()` before creating it.
class LocalService extends GetxService {
  static const _keyVisibleSystems = 'visible_systems';
  static const _keyQuizBestPrefix = 'quiz_best_';
  static const _keyAssemblyStarsPrefix = 'assembly_stars_';
  static const _keyAssemblyTimePrefix = 'assembly_time_';
  static const _keyAssemblyScorePrefix = 'assembly_score_';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyGraphicsQuality = 'graphics_quality';
  static const _keyAssemblyTutorialSeen = 'assembly_tutorial_seen';
  static const _keyBoneBuilderBest = 'bone_builder_best';

  LocalService({GetStorage? box}) : _box = box ?? GetStorage() {
    soundEnabled = (_box.read<bool>(_keySoundEnabled) ?? true).obs;
    graphicsQuality = GraphicsQuality.fromName(_box.read<String>(_keyGraphicsQuality)).obs;
  }

  final GetStorage _box;

  /// Viewer sound effects; every live ViewerBridge follows it.
  late final RxBool soundEnabled;

  /// Viewer rendering quality; every live ViewerBridge follows it.
  late final Rx<GraphicsQuality> graphicsQuality;

  Future<void> setSoundEnabled(bool enabled) {
    soundEnabled.value = enabled;
    return _box.write(_keySoundEnabled, enabled);
  }

  Future<void> setGraphicsQuality(GraphicsQuality quality) {
    graphicsQuality.value = quality;
    return _box.write(_keyGraphicsQuality, quality.name);
  }

  /// Whether the assembly game tutorial was dismissed once.
  bool get assemblyTutorialSeen => _box.read<bool>(_keyAssemblyTutorialSeen) ?? false;

  Future<void> setAssemblyTutorialSeen(bool seen) => _box.write(_keyAssemblyTutorialSeen, seen);

  /// Systems shown on the home screen, restored on next launch.
  List<BodySystem> get visibleSystems {
    final names = _box.read<List<dynamic>>(_keyVisibleSystems);
    if (names == null) return const [BodySystem.skeletal];
    return names.cast<String>().map(BodySystem.fromName).toList();
  }

  Future<void> saveVisibleSystems(Iterable<BodySystem> systems) =>
      _box.write(_keyVisibleSystems, systems.map((s) => s.name).toList());

  int quizBest(BodySystem system) => _box.read<int>('$_keyQuizBestPrefix${system.name}') ?? 0;

  /// Stores [score] if it beats the current best; returns whether it did.
  Future<bool> saveQuizScore(BodySystem system, int score) async {
    if (score <= quizBest(system)) return false;
    await _box.write('$_keyQuizBestPrefix${system.name}', score);
    return true;
  }

  /// Best stars (0 = never finished) of the assembly level [levelId].
  int assemblyStars(String levelId) => _box.read<int>('$_keyAssemblyStarsPrefix$levelId') ?? 0;

  /// Fastest finish of the assembly level [levelId], in seconds.
  int? assemblyBestSeconds(String levelId) => _box.read<int>('$_keyAssemblyTimePrefix$levelId');

  /// Highest score of the assembly level [levelId].
  int? assemblyBestScore(String levelId) => _box.read<int>('$_keyAssemblyScorePrefix$levelId');

  /// Keeps the best stars, time and score separately; returns whether any
  /// of them improved.
  Future<bool> saveAssemblyResult(String levelId, {required int stars, required int seconds, int? score}) async {
    var improved = false;
    if (stars > assemblyStars(levelId)) {
      await _box.write('$_keyAssemblyStarsPrefix$levelId', stars);
      improved = true;
    }
    final best = assemblyBestSeconds(levelId);
    if (best == null || seconds < best) {
      await _box.write('$_keyAssemblyTimePrefix$levelId', seconds);
      improved = true;
    }
    if (score != null) {
      final bestScore = assemblyBestScore(levelId);
      if (bestScore == null || score > bestScore) {
        await _box.write('$_keyAssemblyScorePrefix$levelId', score);
        improved = true;
      }
    }
    return improved;
  }

  /// Best score of the creative bone builder (null = never tested).
  int? get boneBuilderBest => _box.read<int>(_keyBoneBuilderBest);

  /// Stores [score] if it beats the best; returns whether it did.
  Future<bool> saveBoneBuilderScore(int score) async {
    final best = boneBuilderBest;
    if (best != null && score <= best) return false;
    await _box.write(_keyBoneBuilderBest, score);
    return true;
  }
}
