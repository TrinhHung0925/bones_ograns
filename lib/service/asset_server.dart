import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../resource/app_resource.dart';

/// Serves the viewer page and 3D models from the Flutter asset bundle over
/// loopback HTTP. WebViews block ES modules and fetch() on file:// URLs, so
/// the page needs a real origin.
class AssetServer extends GetxService {
  static const _contentTypes = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'json': 'application/json',
    'glb': 'model/gltf-binary',
  };

  HttpServer? _server;

  Uri get viewerUri => Uri.parse('http://127.0.0.1:${_server!.port}${AnatomyAsset.viewerPage}');

  Future<AssetServer> init() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
    return this;
  }

  @override
  void onClose() {
    _server?.close(force: true);
    super.onClose();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final key = 'assets${Uri.decodeComponent(request.uri.path)}';
    if (!AnatomyAsset.servedDirs.any(key.startsWith) || key.contains('..')) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    try {
      final data = await rootBundle.load(key);
      final ext = key.split('.').last;
      response.headers.set(HttpHeaders.contentTypeHeader, _contentTypes[ext] ?? 'application/octet-stream');
      response.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } on FlutterError {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}
