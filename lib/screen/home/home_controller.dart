import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../common/anatomy_viewer/anatomy_viewer.dart';
import '../../dialog/quiz_system_dialog.dart';
import '../../dialog/settings_dialog.dart';
import '../../model/anatomy_part.dart';
import '../../model/body_system.dart';
import '../../model/part_state.dart';
import '../../route.dart';
import '../../service/anatomy_service.dart';
import '../../service/local_service.dart';
import '../../service/progress_service.dart';
import '../../service/tts_service.dart';

/// Explore screen; its state mirrors what the viewer is showing.
class HomeController extends GetxController {
  final anatomy = Get.find<AnatomyService>();
  final _local = Get.find<LocalService>();
  final _tts = Get.find<TtsService>();
  final progress = Get.find<ProgressService>();
  final viewer = ViewerBridge();

  /// Horizontal row of system tiles; scrolls the toggled/revealed tile to the middle.
  final tileScroll = AutoScrollController(axis: Axis.horizontal);
  late final StreamSubscription<ViewerEvent> _sub;

  final visibleSystems = <BodySystem>{}.obs;
  final loadingSystems = <BodySystem>{}.obs;
  final partStates = <String, PartState>{}.obs;
  final selected = Rxn<AnatomyPart>();
  final ready = false.obs;
  final error = RxnString();

  bool get isLoading => !ready.value || loadingSystems.isNotEmpty;

  /// Nothing to look at yet: the page or every visible system is loading.
  bool get isFirstLoad => !ready.value || visibleSystems.every(loadingSystems.contains);

  /// Systems being loaded, for the loading screen ("Xương · Cơ").
  String get loadingLabel => (loadingSystems.isEmpty ? visibleSystems : loadingSystems).map((s) => s.label).join(' · ');
  PartState stateOf(String partId) => partStates[partId] ?? PartState.visible;

  /// Systems with parts in the data set, in tile order.
  late final List<BodySystem> systems = BodySystem.values.where((s) => anatomy.countIn(s) > 0).toList(growable: false);

  /// Parts drawn in the viewer: visible systems minus parts hidden by hand.
  int get visiblePartCount {
    var count = 0;
    for (final system in visibleSystems) {
      count += anatomy.countIn(system);
    }
    for (final entry in partStates.entries) {
      if (entry.value == PartState.hidden && visibleSystems.contains(anatomy.byId(entry.key)?.system)) {
        count--;
      }
    }
    return count;
  }

  @override
  void onInit() {
    super.onInit();
    _sub = viewer.events.listen(_onEvent);
    for (final system in _local.visibleSystems) {
      visibleSystems.add(system);
      viewer.setSystemVisible(system, true);
    }
  }

  @override
  void onReady() {
    super.onReady();
    final first = systems.where(visibleSystems.contains).firstOrNull;
    if (first != null) scrollToSystem(first);
  }

  @override
  void onClose() {
    tileScroll.dispose();
    _sub.cancel();
    viewer.dispose();
    super.onClose();
  }

  void _onEvent(ViewerEvent event) {
    switch (event) {
      case ViewerReady():
        ready.value = true;
      case SystemLoading(:final system):
        loadingSystems.add(system);
      case SystemLoaded(:final system):
        loadingSystems.remove(system);
      case PartTapped(:final partId, :final doubleTap):
        if (doubleTap && partId != null) {
          viewer.focus(partId);
        } else {
          _select(anatomy.byId(partId));
        }
      case ViewerError(:final message):
        error.value = message;
        loadingSystems.clear();
    }
  }

  void _select(AnatomyPart? part) {
    selected.value = part;
    viewer.select(part?.id);
  }

  void setSystemVisible(BodySystem system, bool visible) {
    if (visible) {
      visibleSystems.add(system);
    } else {
      visibleSystems.remove(system);
      if (selected.value?.system == system) _select(null);
    }
    viewer.setSystemVisible(system, visible);
    _local.saveVisibleSystems(visibleSystems);
  }

  void toggleSystem(BodySystem system) {
    setSystemVisible(system, !visibleSystems.contains(system));
    scrollToSystem(system);
  }

  /// Animates [system]'s tile to the middle of the tile row.
  void scrollToSystem(BodySystem system) {
    final index = systems.indexOf(system);
    if (index < 0 || !tileScroll.hasClients) return;
    tileScroll.scrollToIndex(index, preferPosition: AutoScrollPosition.middle);
  }

  /// Selects a part found by search, revealing its system first if needed.
  void reveal(AnatomyPart part) {
    if (!visibleSystems.contains(part.system)) setSystemVisible(part.system, true);
    if (stateOf(part.id) != PartState.visible) setPartState(part.id, PartState.visible);
    _select(part);
    viewer.focus(part.id);
    scrollToSystem(part.system);
  }

  void clearSelection() => _select(null);

  void setPartState(String partId, PartState state) {
    if (state == PartState.visible) {
      partStates.remove(partId);
    } else {
      partStates[partId] = state;
    }
    viewer.setPartState(partId, state);
    if (state == PartState.hidden && selected.value?.id == partId) _select(null);
  }

  void toggleGhostSelected() {
    final part = selected.value;
    if (part == null) return;
    final ghosted = stateOf(part.id) == PartState.ghost;
    setPartState(part.id, ghosted ? PartState.visible : PartState.ghost);
  }

  void hideSelected() {
    final part = selected.value;
    if (part != null) setPartState(part.id, PartState.hidden);
  }

  void isolateSelected() {
    final part = selected.value;
    if (part == null) return;
    // The viewer ghosts every part of the visible systems except this one.
    partStates.assignAll({
      for (final p in anatomy.parts)
        if (p.id != part.id && visibleSystems.contains(p.system)) p.id: PartState.ghost,
    });
    viewer.isolate(part.id);
    viewer.focus(part.id);
  }

  void showAll() {
    partStates.clear();
    viewer.showAll();
  }

  void focusSelected() {
    final part = selected.value;
    if (part != null) viewer.focus(part.id);
  }

  void resetCamera() => viewer.resetCamera();

  /// Reads the English name aloud (pronunciation practice).
  void speakSelected() {
    final part = selected.value;
    if (part != null) _tts.speak(part.name);
  }

  Future<void> openSearch() async {
    final part = await Get.toNamed(AppPage.partSearch.routeName);
    if (part is AnatomyPart) reveal(part);
  }

  Future<void> openQuiz() async {
    final system = await QuizSystemDialog.show(anatomy);
    if (system != null) Get.toNamed(AppPage.quiz.routeName, arguments: system);
  }

  void openAssembly() => Get.toNamed(AppPage.assemblyLevels.routeName);

  void openLearn() => Get.toNamed(AppPage.learnHub.routeName);

  void openAbout() => Get.toNamed(AppPage.about.routeName);

  void openSettings() => SettingsDialog.show();

  void onBack() {
    Get.back();
  }
}
