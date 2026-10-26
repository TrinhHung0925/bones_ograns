import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'screen/about/about_view.dart';
import 'screen/assembly/assembly_view.dart';
import 'screen/assembly_levels/assembly_levels_view.dart';
import 'screen/bone_builder/bone_builder_view.dart';
import 'screen/daily/daily_view.dart';
import 'screen/exam/exam_view.dart';
import 'screen/exam_setup/exam_setup_view.dart';
import 'screen/home/home_view.dart';
import 'screen/learn_hub/learn_hub_view.dart';
import 'screen/lesson/lesson_view.dart';
import 'screen/lessons/lessons_view.dart';
import 'screen/mistakes/mistakes_view.dart';
import 'screen/part_search/part_search_view.dart';
import 'screen/quiz/quiz_view.dart';
import 'screen/splash/splash_view.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  GetPageRoute page(RouteSettings settings, Widget Function() genPage, [Bindings? bindings]) {
    var page = GetPage(name: settings.name!, page: genPage, arguments: settings.arguments, binding: bindings);
    return PageRedirect(route: page, unknownRoute: page).page();
  }

  switch (settings.name) {
    case "/splash":
      return page(settings, () => SplashView());
    case "/home":
      return page(settings, () => HomeView());
    case "/partSearch":
      return page(settings, () => PartSearchView());
    case "/quiz":
      return page(settings, () => QuizView());
    case "/about":
      return page(settings, () => AboutView());
    case "/assemblyLevels":
      return page(settings, () => AssemblyLevelsView());
    case "/assembly":
      return page(settings, () => AssemblyView());
    case "/daily":
      return page(settings, () => DailyView());
    case "/examSetup":
      return page(settings, () => ExamSetupView());
    case "/exam":
      return page(settings, () => ExamView());
    case "/mistakes":
      return page(settings, () => MistakesView());
    case "/learnHub":
      return page(settings, () => LearnHubView());
    case "/lessons":
      return page(settings, () => LessonsView());
    case "/lesson":
      return page(settings, () => LessonView());
    case "/boneBuilder":
      return page(settings, () => BoneBuilderView());

    default:
      return page(
        settings,
        () => Scaffold(
          appBar: AppBar(title: const Text('404')),
          body: Center(child: Text('No route defined for ${settings.name}')),
        ),
      );
  }
}

enum AppPage { splash, home, partSearch, quiz, about, assemblyLevels, assembly, daily, examSetup, exam, mistakes, learnHub, lessons, lesson, boneBuilder }

extension AppPageExtension on AppPage {
  String get routeName {
    switch (this) {
      case AppPage.splash:
        return '/${AppPage.splash.name}';
      case AppPage.home:
        return '/${AppPage.home.name}';
      case AppPage.partSearch:
        return '/${AppPage.partSearch.name}';
      case AppPage.quiz:
        return '/${AppPage.quiz.name}';
      case AppPage.about:
        return '/${AppPage.about.name}';
      case AppPage.assemblyLevels:
        return '/${AppPage.assemblyLevels.name}';
      case AppPage.assembly:
        return '/${AppPage.assembly.name}';
      case AppPage.daily:
        return '/${AppPage.daily.name}';
      case AppPage.examSetup:
        return '/${AppPage.examSetup.name}';
      case AppPage.exam:
        return '/${AppPage.exam.name}';
      case AppPage.mistakes:
        return '/${AppPage.mistakes.name}';
      case AppPage.learnHub:
        return '/${AppPage.learnHub.name}';
      case AppPage.lessons:
        return '/${AppPage.lessons.name}';
      case AppPage.lesson:
        return '/${AppPage.lesson.name}';
      case AppPage.boneBuilder:
        return '/${AppPage.boneBuilder.name}';
    }
  }
}
