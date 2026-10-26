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
  final _pending = <String>[];
  final _settingsSubs = <StreamSubscription<Object?>>[];
  bool _ready = false;

  Stream<ViewerEvent> get events => _events.stream;

  Stream<AssemblyEvent> get assemblyEvents => _assemblyEvents.stream;

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
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

  void showAll() => _call('showAll');

  void focus(String partId) => _call('focus', [partId]);

  void resetCamera() => _call('resetCamera');

  /// Button zoom, for when pinching is awkward (simulator, one hand).
  void zoomIn() => _call('zoomBy', [0.7]);

  void zoomOut() => _call('zoomBy', [1.43]);

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

  void dispose() {
    for (final sub in _settingsSubs) {
      sub.cancel();
    }
    _events.close();
    _assemblyEvents.close();
  }
}
