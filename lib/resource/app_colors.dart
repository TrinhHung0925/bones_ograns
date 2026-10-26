import 'package:flutter/material.dart';

/// Dark "casual game" palette: chunky blocks whose darker *Depth colour is
/// drawn underneath as a bottom edge, so surfaces read as pressable tiles.
abstract class AppColors {
  static const Color background = Color(0xFF130F2B);
  static const Color backgroundGlow = Color(0xFF2A2160);

  static const Color surface = Color(0xFF221C48);
  static const Color surfaceDepth = Color(0xFF0D0A21);
  static const Color surfaceRaised = Color(0xFF2E2761);
  static const Color border = Color(0xFF362E70);

  static const Color primary = Color(0xFF6A55FF);
  static const Color primaryDepth = Color(0xFF4331C4);
  static const Color primarySoft = Color(0xFF3B2F8F);

  static const Color accent = Color(0xFFFFCB4C);
  static const Color accentDepth = Color(0xFFCF9414);
  static const Color onAccent = Color(0xFF1D1638);

  static const Color textPrimary = Color(0xFFF5F3FF);
  static const Color textSecondary = Color(0xFFB3ADDF);
  static const Color textMuted = Color(0xFF7D76AD);

  /// Quiz feedback, also flashed on the tapped part.
  static const Color correct = Color(0xFF3EDC8B);
  static const Color wrong = Color(0xFFFF5C7A);
  static const Color star = Color(0xFFFFCB4C);

  /// Body systems (tiles and badges; the 3D materials live in assets/viewer/materials.js).
  static const Color skeletal = Color(0xFFE9DFC9);

  /// Cartilage: pale, cool blue-white, apart from the warm bone and the saturated sensory blue.
  static const Color joint = Color(0xFFBFE2F2);
  static const Color muscular = Color(0xFFE0675C);
  static const Color cardiovascular = Color(0xFFFF4D5E);

  /// Lymph green, yellower than the quiz "correct" green.
  static const Color lymphatic = Color(0xFF9AD66B);
  static const Color nervous = Color(0xFFF0C94C);
  static const Color respiratory = Color(0xFFF29BB0);
  static const Color digestive = Color(0xFFF09A6E);
  static const Color urinary = Color(0xFFE2B54F);
  static const Color reproductive = Color(0xFFD884B0);
  static const Color endocrine = Color(0xFFB394FF);
  static const Color sensory = Color(0xFF6CC8F2);
  static const Color integumentary = Color(0xFFEDB898);
  static const Color other = Color(0xFF9AA4C0);
}
