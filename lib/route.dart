import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'screen/about/about_view.dart';
import 'screen/assembly/assembly_view.dart';
import 'screen/assembly_levels/assembly_levels_view.dart';
import 'screen/home/home_view.dart';
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

enum AppPage { splash, home, partSearch, quiz, about, assemblyLevels, assembly }

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
    }
  }
}
