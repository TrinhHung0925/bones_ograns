// Smoke test of the main flows on a booted iOS simulator:
// SIM_ID=<simulator-id> SIM_SHOT_DIR=/tmp/shots flutter drive --target test_driver/app.dart \
//   --driver test_driver/app_test.dart -d <simulator-id>
//
// The 3D view is a WebView, so taps on the model are not driven here;
// screenshots come from simctl because driver screenshots omit platform views.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  late FlutterDriver driver;
  final shotDir = Platform.environment['SIM_SHOT_DIR'];
  final simId = Platform.environment['SIM_ID'] ?? 'booted';

  Future<void> shot(String name) async {
    if (shotDir == null) return;
    await Process.run('xcrun', ['simctl', 'io', simId, 'screenshot', '$shotDir/$name.png']);
  }

  Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  tearDownAll(() async {
    await driver.close();
  });

  test('home loads the viewer', () async {
    await driver.waitFor(find.byTooltip('Tìm kiếm'), timeout: const Duration(seconds: 30));
    await pause(5000);
    await shot('1_home');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('search reveals a part and the part card acts on it', () async {
    await driver.tap(find.byTooltip('Tìm kiếm'));
    await driver.waitFor(find.byType('TextField'));
    await driver.tap(find.byType('TextField'));
    await driver.enterText('right femur');
    await driver.waitFor(find.text('Right femur'));
    await shot('2_search');
    await driver.tap(find.text('Right femur'));
    await driver.waitFor(find.text('Tách riêng'));
    await pause(1500);
    await shot('3_selected');
    await driver.tap(find.text('Tách riêng'));
    await pause(1500);
    await shot('4_isolated');
    await driver.tap(find.byTooltip('Hiện tất cả'));
    await driver.tap(find.byTooltip('Đóng'));
    await driver.waitForAbsent(find.text('Tách riêng'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('quiz runs on the skeleton', () async {
    await driver.tap(find.byTooltip('Đố vui vị trí'));
    // The home system tiles stay on screen behind the sheet, so match the
    // picker's own tile.
    final skeletal = find.descendant(of: find.byType('QuizSystemDialog'), matching: find.text('Xương'));
    await driver.waitFor(skeletal);
    await shot('5_quiz_picker');
    await driver.tap(skeletal);
    await driver.waitFor(find.text('CHẠM VÀO'), timeout: const Duration(seconds: 30));
    await pause(1000);
    await shot('6_quiz');
    await driver.tap(find.text('Bỏ qua'));
    await pause(800);
    await shot('7_quiz_reveal');
    await driver.waitFor(find.text('Câu 2/10'), timeout: const Duration(seconds: 10));
    await driver.tap(find.byTooltip('Back'));
    await driver.waitFor(find.byTooltip('Tìm kiếm'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('settings sheet opens from the home header', () async {
    await driver.tap(find.byTooltip('Cài đặt'));
    await driver.waitFor(find.text('Chất lượng đồ họa'));
    await shot('8a_settings');
    await driver.tap(find.text('Thấp'));
    await driver.tap(find.text('Cao'));
    // "Xem lại hướng dẫn" closes the sheet and opens the tutorial.
    await driver.tap(find.text('Xem lại hướng dẫn'));
    // The tutorial's hand animation loops, so frame-synced commands would wait forever.
    await driver.runUnsynchronized(() async {
      await driver.waitFor(find.text('Bắt đầu'));
      await shot('8b_tutorial');
      await driver.tap(find.text('Bắt đầu'));
      await driver.waitForAbsent(find.text('Bắt đầu'));
    });
    await driver.waitFor(find.byTooltip('Tìm kiếm'));
  });

  test('about screen opens', () async {
    await driver.tap(find.byTooltip('Thông tin'));
    await driver.waitFor(find.text('Thông tin'));
    await shot('8_about');
    await driver.tap(find.byTooltip('Back'));
    await driver.waitFor(find.byTooltip('Tìm kiếm'));
  });

  test('system tile toggles muscles', () async {
    await driver.waitFor(find.text('Cơ'));
    await driver.tap(find.text('Cơ'));
    await pause(4000);
    await shot('9_muscles');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('assembly game opens a level and scatters the pieces', () async {
    await driver.tap(find.text('Ghép cơ thể 3D'));
    await driver.waitFor(find.text('Chi trên phải'));
    await shot('10_levels');
    await driver.tap(find.text('Chi trên phải'));
    // The how-to-play overlay shows on the first game only; its hand
    // animation loops, so frame-synced commands would wait forever.
    await driver.runUnsynchronized(() async {
      try {
        await driver.waitFor(find.text('Bắt đầu'), timeout: const Duration(seconds: 3));
        await shot('11a_tutorial');
        await driver.tap(find.text('Bắt đầu'));
      } on DriverError {
        // Already seen on an earlier run.
      }
    });
    await driver.waitFor(find.text('Gợi ý'), timeout: const Duration(seconds: 30));
    await pause(4000);
    await shot('11_assembly');
    await driver.tap(find.byTooltip('Back'));
    await driver.waitFor(find.text('Chi trên phải'));
    await driver.tap(find.byTooltip('Back'));
    await driver.waitFor(find.byTooltip('Tìm kiếm'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
