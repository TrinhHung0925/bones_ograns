import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../model/body_system.dart';

/// Small persistent preferences. Call `GetStorage.init()` before creating it.
class LocalService extends GetxService {
  static const _keyVisibleSystems = 'visible_systems';
  static const _keyQuizBestPrefix = 'quiz_best_';

  final _box = GetStorage();

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
}
