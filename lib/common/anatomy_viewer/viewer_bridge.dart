import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../model/assembly_piece.dart';
import '../../model/body_system.dart';
import '../../model/graphics_quality.dart';
import '../../model/part_state.dart';
import '../../resource/app_colors.dart';
import '../../service/asset_server.dart';
import '../../service/local_service.dart';

sealed class ViewerEvent {
  const ViewerEvent();
}

class ViewerReady extends ViewerEvent {
  const ViewerReady();
}

class SystemLoading extends ViewerEvent {
  const SystemLoading(this.system);
  final BodySystem system;
}

class SystemLoaded extends ViewerEvent {
  const SystemLoaded(this.system);
  final BodySystem system;
}

/// A tap on the model. [partId] is null when the tap hit empty space.
class PartTapped extends ViewerEvent {
  const PartTapped(this.partId, {required this.doubleTap});
  final String? partId;
  final bool doubleTap;
}

class ViewerError extends ViewerEvent {
  const ViewerError(this.message);
  final String message;
}

/// Events of the assembly game, on [ViewerBridge.assemblyEvents]. Kept apart
/// from [ViewerEvent] so screens that switch over it stay exhaustive.
sealed class AssemblyEvent {
  const AssemblyEvent();
}

/// Assembly game: the level's pieces are scattered and ready to drag.
class AssemblyReady extends AssemblyEvent {
  const AssemblyReady(this.count);
  final int count;
}

/// Assembly game: the user picked up a loose piece.
class PieceGrabbed extends AssemblyEvent {
  const PieceGrabbed(this.partId);
  final String partId;
}

/// Assembly game: a piece was dropped on its own slot; [remaining] are loose.
class PieceSnapped extends AssemblyEvent {
  const PieceSnapped(this.partId, this.remaining);
  final String partId;
  final int remaining;
}

/// Assembly game: a piece was dropped on another piece's slot ([slotId]).
class PieceWrong extends AssemblyEvent {
  const PieceWrong(this.partId, this.slotId);
  final String partId;
  final String slotId;
}

/// Assembly game: the slot of [partId] is pulsing as a hint.
class HintShown extends AssemblyEvent {
  const HintShown(this.partId);
  final String partId;
}

/// Assembly game: every piece is in place.
class AssemblyComplete extends AssemblyEvent {
  const AssemblyComplete();
}

/// Assembly game: [count] pieces snapped in a row without a wrong drop.
class ComboEvent extends AssemblyEvent {
  const ComboEvent(this.count);
  final int count;
}

/// Phase of the creative builder's stability test.
enum BuilderPhase {
  settle,
  quake,
  impact;

  static BuilderPhase fromName(String? name) => values.firstWhere((p) => p.name == name, orElse: () => settle);
}

/// Events of the creative bone builder, on [ViewerBridge.builderEvents]. Kept
/// apart from [ViewerEvent] and [AssemblyEvent] like the assembly game.
sealed class BuilderEvent {
  const BuilderEvent();
}

/// Builder: pieces are laid out; [baseline] is the anatomical skeleton's metric.
class BuilderReady extends BuilderEvent {
  const BuilderReady({required this.baseline, required this.pieceCount});
  final num baseline;
  final int pieceCount;
}

/// Builder: the selected piece changed; [id] is null when none is selected.
class BuilderSelected extends BuilderEvent {
  const BuilderSelected(this.id);
  final String? id;
}

/// Builder: the structure changed; [placed] pieces are in the build.
class BuilderChanged extends BuilderEvent {
  const BuilderChanged({required this.placed, required this.canUndo});
  final int placed;
  final bool canUndo;
}

/// Builder: the stability test entered [phase].
class BuilderTesting extends BuilderEvent {
  const BuilderTesting(this.phase);
  final BuilderPhase phase;
}

/// Builder: the stability test finished. [score] is 100 for the anatomical
/// skeleton and may exceed it.
class BuilderResult extends BuilderEvent {
  const BuilderResult({
    required this.score,
    required this.metric,
    required this.baseline,
    required this.heightKept,
    required this.jointsKept,
    required this.jointsTotal,
    required this.piecesUsed,
    required this.stable,
  });

  factory BuilderResult.fromJson(Map<String, dynamic> data) => BuilderResult(
    score: (data['score'] as num? ?? 0).round(),
    metric: data['metric'] as num? ?? 0,
    baseline: data['baseline'] as num? ?? 0,
    heightKept: data['heightKept'] as num? ?? 0,
    jointsKept: (data['jointsKept'] as num? ?? 0).toInt(),
    jointsTotal: (data['jointsTotal'] as num? ?? 0).toInt(),
    piecesUsed: (data['piecesUsed'] as num? ?? 0).toInt(),
    stable: data['stable'] as bool? ?? false,
  );

  final int score;
  final num metric;
  final num baseline;

  /// Share (0–1) of the structure's height left standing.
  final num heightKept;
  final int jointsKept;
  final int jointsTotal;
  final int piecesUsed;
  final bool stable;
}

/// Drives the three.js page in `assets/viewer`. Swapping the rendering engine
/// later only needs a new implementation of these commands and events.
class ViewerBridge {
  ViewerBridge() {
    webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel('Bridge', onMessageReceived: _onMessage)
      ..loadRequest(Get.find<AssetServer>().viewerUri);
    _applySettings();
  }

  /// Sends the saved sound and quality settings ahead of every other command
  /// (they queue until the page is ready) and follows later changes.
  void _applySettings() {
    if (!Get.isRegistered<LocalService>()) return;
    final local = Get.find<LocalService>();
    setSoundEnabled(local.soundEnabled.value);
    setQuality(local.graphicsQuality.value);
    _settingsSubs.add(local.soundEnabled.listen(setSoundEnabled));
    _settingsSubs.add(local.graphicsQuality.listen(setQuality));
  }

  late final WebViewController webView;
  final _events = StreamController<ViewerEvent>.broadcast();
  final _assemblyEvents = StreamController<AssemblyEvent>.broadcast();
  final _builderEvents = StreamController<BuilderEvent>.broadcast();
  final _pending = <String>[];
  final _settingsSubs = <StreamSubscription<Object?>>[];
  bool _ready = false;

  Stream<ViewerEvent> get events => _events.stream;

  Stream<AssemblyEvent> get assemblyEvents => _assemblyEvents.stream;

  Stream<BuilderEvent> get builderEvents => _builderEvents.stream;

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
    final builder = switch (data['type']) {
      'builderReady' => BuilderReady(
        baseline: data['baseline'] as num? ?? 0,
        pieceCount: (data['pieceCount'] as num? ?? 0).toInt(),
      ),
      'builderSelected' => BuilderSelected(data['id'] as String?),
      'builderChanged' => BuilderChanged(
        placed: (data['placed'] as num? ?? 0).toInt(),
        canUndo: data['canUndo'] as bool? ?? false,
      ),
      'builderTesting' => BuilderTesting(BuilderPhase.fromName(data['phase'] as String?)),
      'builderResult' => BuilderResult.fromJson(data),
      _ => null,
    };
    if (builder != null) {
      if (!_builderEvents.isClosed) _builderEvents.add(builder);
      return;
    }
    final assembly = switch (data['type']) {
      'assemblyReady' => AssemblyReady(data['count'] as int),
      'pieceGrabbed' => PieceGrabbed(data['id'] as String),
      'pieceSnapped' => PieceSnapped(data['id'] as String, data['remaining'] as int),
      'pieceWrong' => PieceWrong(data['id'] as String, data['slotId'] as String),
      'hintShown' => HintShown(data['id'] as String),
      'assemblyComplete' => const AssemblyComplete(),
      'combo' => ComboEvent((data['count'] as num).toInt()),
      _ => null,
    };
    if (assembly != null) {
      if (!_assemblyEvents.isClosed) _assemblyEvents.add(assembly);
      return;
    }
    final event = switch (data['type']) {
      'ready' => const ViewerReady(),
      'systemLoading' => SystemLoading(BodySystem.fromName(data['system'] as String)),
      'systemLoaded' => SystemLoaded(BodySystem.fromName(data['system'] as String)),
      'tap' => PartTapped(data['id'] as String?, doubleTap: false),
      'doubleTap' => PartTapped(data['id'] as String?, doubleTap: true),
      'error' => ViewerError(data['message'] as String? ?? ''),
      _ => null,
    };
    if (event == null) return;
    if (event is ViewerReady) {
      _ready = true;
      for (final js in _pending) {
        webView.runJavaScript(js);
      }
      _pending.clear();
    }
    if (event is ViewerError) debugPrint('ViewerBridge: ${event.message}');
    if (!_events.isClosed) _events.add(event);
  }

  void _call(String cmd, [List<Object?> args = const []]) {
    final js = 'window.anatomy.call(${jsonEncode({'cmd': cmd, 'args': args})})';
    if (_ready) {
      webView.runJavaScript(js);
    } else {
      _pending.add(js);
    }
  }

  void setSystemVisible(BodySystem system, bool visible) => _call('setSystemVisible', [system.name, visible]);

  void select(String? partId) => _call('select', [partId]);

  void setPartState(String partId, PartState state) => _call('setPartState', [partId, state.name]);

  void isolate(String partId) => _call('isolate', [partId]);

  /// Ghosts the solid parts that enclose [partId] (e.g. heart walls around a
  /// valve), so it can be seen and tapped.
  void ghostEnclosing(String partId) => _call('ghostEnclosing', [partId]);

  void showAll() => _call('showAll');

  void focus(String partId) => _call('focus', [partId]);

  void resetCamera() => _call('resetCamera');

  /// Button zoom, for when pinching is awkward (simulator, one hand).
  void zoomIn() => _call('zoomBy', [0.7]);

  void zoomOut() => _call('zoomBy', [1.43]);

  /// One-finger drag pans (like moving a photo) instead of rotating.
  void setPanMode(bool pan) => _call('setDragMode', [pan ? 'pan' : 'rotate']);

  void flash(String partId, Color color, {Duration duration = const Duration(milliseconds: 900)}) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    _call('flash', [partId, hex, duration.inMilliseconds]);
  }

  /// Turns the viewer's sound effects on or off.
  void setSoundEnabled(bool enabled) => _call('setSoundEnabled', [enabled]);

  /// Switches the rendering quality ('high' or 'low').
  void setQuality(GraphicsQuality quality) => _call('setQuality', [quality.name]);

  /// Starts the assembly game, whose systems must already be visible. Each
  /// entry of [pieces] is a part id or an [AssemblyPiece] (a group is sent
  /// as `{id, parts}` and its events carry the group id). [view] is the
  /// direction from the level towards the camera.
  void assemblyStart(List<Object> pieces, {List<double> view = const [0, 0, 1]}) => _call('assemblyStart', [
    [for (final p in pieces) p is AssemblyPiece ? p.toJson() : p],
    {'view': view},
  ]);

  /// Pulses the slot of piece [partId] (a part or group id), or of a random
  /// loose piece when null.
  void assemblyHint([String? partId]) => _call('assemblyHint', [partId]);

  /// Leaves the assembly game and restores the normal scene.
  void assemblyEnd() => _call('assemblyEnd');

  /// Starts the creative bone builder; each piece is
  /// `{id, name, partIds}`. The viewer loads the skeleton itself.
  void builderStart(List<Map<String, Object>> pieces) => _call('builderStart', [
    {'pieces': pieces},
  ]);

  /// Turns the selected builder piece by [degrees] around [axis] ('x', 'y' or 'z').
  void builderRotate(String axis, num degrees) => _call('builderRotate', [
    {'axis': axis, 'degrees': degrees},
  ]);

  void builderUndo() => _call('builderUndo', [<String, Object>{}]);

  /// Lays the pieces out loose again.
  void builderReset() => _call('builderReset', [<String, Object>{}]);

  /// Puts every piece in its anatomical place (the 100-point reference).
  void builderAnatomical() => _call('builderAnatomical', [<String, Object>{}]);

  /// Runs the stability test (settle, earthquake, heavy ball).
  void builderTest() => _call('builderTest', [<String, Object>{}]);

  /// Back to building after a test, with the structure as it was built.
  void builderEdit() => _call('builderEdit', [<String, Object>{}]);

  /// Leaves the builder and restores the normal scene.
  void builderStop() => _call('builderStop', [<String, Object>{}]);

  void dispose() {
    for (final sub in _settingsSubs) {
      sub.cancel();
    }
    _events.close();
    _assemblyEvents.close();
    _builderEvents.close();
  }
}
