import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../model/body_system.dart';
import '../../model/part_state.dart';
import '../../resource/app_colors.dart';
import '../../service/asset_server.dart';

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

/// Drives the three.js page in `assets/viewer`. Swapping the rendering engine
/// later only needs a new implementation of these commands and events.
class ViewerBridge {
  ViewerBridge() {
    webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel('Bridge', onMessageReceived: _onMessage)
      ..loadRequest(Get.find<AssetServer>().viewerUri);
  }

  late final WebViewController webView;
  final _events = StreamController<ViewerEvent>.broadcast();
  final _pending = <String>[];
  bool _ready = false;

  Stream<ViewerEvent> get events => _events.stream;

  void _onMessage(JavaScriptMessage message) {
    final data = jsonDecode(message.message) as Map<String, dynamic>;
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

  void setSystemVisible(BodySystem system, bool visible) =>
      _call('setSystemVisible', [system.name, visible]);

  void select(String? partId) => _call('select', [partId]);

  void setPartState(String partId, PartState state) =>
      _call('setPartState', [partId, state.name]);

  void isolate(String partId) => _call('isolate', [partId]);

  void showAll() => _call('showAll');

  void focus(String partId) => _call('focus', [partId]);

  void resetCamera() => _call('resetCamera');

  void flash(String partId, Color color, {Duration duration = const Duration(milliseconds: 900)}) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    _call('flash', [partId, hex, duration.inMilliseconds]);
  }

  void dispose() => _events.close();
}
