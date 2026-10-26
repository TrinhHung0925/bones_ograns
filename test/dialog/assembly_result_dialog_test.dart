import 'package:bones_ograns/dialog/assembly_result_dialog.dart';
import 'package:bones_ograns/resource/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool hasNext, bool isBestScore = false}) async {
    tester.view.physicalSize = const Size(390, 884) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 884),
        builder: (_, _) => GetMaterialApp(
          home: Scaffold(
            body: AssemblyResultDialog(
              stars: 2,
              time: const Duration(minutes: 1, seconds: 5),
              mistakes: 3,
              hints: 0,
              isRecord: true,
              hasNext: hasNext,
              score: 640,
              timeBonus: 40,
              maxCombo: 4,
              isBestScore: isBestScore,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows stats and every action without overflow', (tester) async {
    await pump(tester, hasNext: true);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text(AppText.assemblyNewRecord), findsOneWidget);
    expect(find.text(AppText.assemblyNext), findsOneWidget);
    expect(find.text(AppText.assemblyReplay), findsOneWidget);
    expect(find.text(AppText.assemblyToList), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the score with its bonuses and a new best score', (tester) async {
    await pump(tester, hasNext: true, isBestScore: true);
    expect(find.text('640'), findsOneWidget);
    expect(find.textContaining('x4'), findsOneWidget);
    expect(find.text(AppText.assemblyNewBestScore), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides "next" on the last level', (tester) async {
    await pump(tester, hasNext: false);
    expect(find.text(AppText.assemblyNext), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
