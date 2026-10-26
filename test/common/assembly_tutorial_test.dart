import 'package:bones_ograns/common/assembly_tutorial.dart';
import 'package:bones_ograns/resource/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('tutorial shows the three steps and starts on tap', (tester) async {
    tester.view.physicalSize = const Size(390, 884) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var started = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 884),
        builder: (_, _) => GetMaterialApp(
          home: Scaffold(body: AssemblyTutorial(onStart: () => started++)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(AppText.tutorialStep1), findsOneWidget);
    expect(find.text(AppText.tutorialStep2), findsOneWidget);
    expect(find.text(AppText.tutorialStep3), findsOneWidget);
    // Let the hand animation run through a whole loop.
    await tester.pump(const Duration(milliseconds: 2400));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(AppText.tutorialStart));
    expect(started, 1);
  });
}
