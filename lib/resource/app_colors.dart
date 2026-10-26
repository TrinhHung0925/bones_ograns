import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color primary = Color(0xFF2F7BFF);
  static const Color background = Color(0xFF12161D);
  static const Color hintBackground = Color(0x73000000);
  static const Color hintText = Colors.white70;

  /// Quiz feedback, flashed on the tapped part.
  static const Color correct = Color(0xFF34C759);
  static const Color wrong = Color(0xFFFF3B30);

  /// Body systems; keep in sync with SYSTEM_COLORS in assets/viewer/viewer.js.
  static const Color skeletal = Color(0xFFE9DFC9);
  static const Color muscular = Color(0xFFB8483E);
  static const Color cardiovascular = Color(0xFFC8323A);
  static const Color nervous = Color(0xFFF0C94C);
  static const Color respiratory = Color(0xFFE59AA8);
  static const Color digestive = Color(0xFFD9906C);
  static const Color urinary = Color(0xFFD1A94F);
  static const Color reproductive = Color(0xFFC97C9C);
  static const Color endocrine = Color(0xFF9D7FD6);
  static const Color sensory = Color(0xFF7FB7DA);
  static const Color integumentary = Color(0xFFE2B79D);
  static const Color other = Color(0xFF9AA4AE);
}
