// TEMPORARY exploratory check (lead): does choosing a different quiz system /
// assembly level really open that choice? Delete after use.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;
  final shotDir = Platform.environment['SIM_SHOT_DIR']!;
  final simId = Platform.environment['SIM_ID']!;

  Future<void> shot(String name) =>
      Process.run('xcrun', ['simctl', 'io', simId, 'screenshot', '$shotDir/$name.png']);
  Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> dismissTutorial() async {
    try {
      await driver.tap(find.text('Bắt đầu'), timeout: const Duration(seconds: 3));
    } catch (_) {}
  }

  setUpAll(() async => driver = await FlutterDriver.connect());
  tearDownAll(() async => driver.close());

  test('quiz opens the chosen system', () async {
    await driver.waitFor(find.byTooltip('Tìm kiếm'), timeout: const Duration(seconds: 30));
    for (final system in ['Cơ', 'Tuần hoàn']) {
      await driver.tap(find.byTooltip('Đố vui vị trí'));
      await driver.tap(find.descendant(of: find.byType('QuizSystemDialog'), matching: find.text(system)));
      await driver.waitFor(find.text('Đố vui · $system'), timeout: const Duration(seconds: 10));
      await pause(6000);
      await shot('quiz_$system');
      await driver.tap(find.byTooltip('Back'));
      await driver.waitFor(find.byTooltip('Tìm kiếm'));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('assembly opens the chosen level', () async {
    await driver.tap(find.text('Ghép xương 3D'));
    final levels = ['Chi trên trái', 'Thận & tiết niệu', 'Nội tạng', 'Bộ xương hoàn chỉnh', 'Toàn thân'];
    for (final (i, level) in levels.indexed) {
      final tile = find.text(level);
      await driver.scrollUntilVisible(find.byType('ListView'), tile, dyScroll: -250);
      await driver.tap(tile);
      await dismissTutorial();
      await pause(8000);
      await shot('level_${i}_$level');
      // Header title must be the chosen level.
      await driver.waitFor(find.descendant(of: find.byType('GameHeader'), matching: find.text(level)));
      await driver.tap(find.byTooltip('Back'));
      await pause(800);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
