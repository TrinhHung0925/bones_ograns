import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

/// Reads anatomical names aloud with the platform's English voice.
class TtsService extends GetxService {
  final _tts = FlutterTts();
  bool _configured = false;

  Future<void> speak(String text) async {
    if (!_configured) {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      _configured = true;
    }
    await _tts.stop();
    await _tts.speak(text);
  }
}
