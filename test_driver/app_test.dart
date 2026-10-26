// Smoke test of the main flows on a booted iOS simulator:
// SIM_SHOT_DIR=/tmp/shots flutter drive --target test_driver/app.dart \
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

  Future<void> shot(String name) async {
    if (shotDir == null) return;
    await Process.run('xcrun', ['simctl', 'io', 'booted', 'screenshot', '$shotDir/$name.png']);
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
    await driver.waitFor(find.text('Xương'));
    await driver.tap(find.text('Xương'));
    await driver.waitFor(find.text('Chạm vào:'), timeout: const Duration(seconds: 30));
    await pause(1000);
    await shot('5_quiz');
    await driver.tap(find.text('Bỏ qua'));
    await pause(800);
    await shot('6_quiz_reveal');
    await driver.waitFor(find.text('Câu 2/10'), timeout: const Duration(seconds: 10));
    await driver.tap(find.pageBack());
    await driver.waitFor(find.byTooltip('Tìm kiếm'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('about screen opens', () async {
    await driver.tap(find.byTooltip('Thông tin'));
    await driver.waitFor(find.text('Nguồn dữ liệu'));
    await shot('7_about');
    await driver.tap(find.pageBack());
    await driver.waitFor(find.byTooltip('Tìm kiếm'));
  });

  test('systems sheet toggles muscles', () async {
    await driver.tap(find.byTooltip('Hệ cơ quan'));
    await driver.waitFor(find.text('Cơ'));
    await driver.tap(find.text('Cơ'));
    await pause(4000);
    await shot('8_systems');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
