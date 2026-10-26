// Entry point for driving the app with flutter_driver:
// flutter run --target test_driver/app.dart
import 'package:bones_ograns/main.dart' as app;
import 'package:flutter_driver/driver_extension.dart';

void main() {
  enableFlutterDriverExtension();
  app.main();
}
