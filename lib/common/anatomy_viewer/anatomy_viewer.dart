import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'viewer_bridge.dart';

export 'viewer_bridge.dart';

class AnatomyViewer extends StatelessWidget {
  const AnatomyViewer({super.key, required this.bridge});

  final ViewerBridge bridge;

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: bridge.webView,
      // The page handles every gesture itself (orbit, pinch, tap).
      gestureRecognizers: {Factory(() => EagerGestureRecognizer())},
    );
  }
}
