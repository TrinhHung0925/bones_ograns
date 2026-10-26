import 'package:flutter/material.dart';

import '../resource/app_colors.dart';

/// Body systems, matching the GLB files in `assets/anatomy/models`.
enum BodySystem {
  skeletal('Xương', Icons.accessibility_new, AppColors.skeletal),
  joint('Khớp & sụn', Icons.join_inner, AppColors.joint),
  muscular('Cơ', Icons.fitness_center, AppColors.muscular),
  cardiovascular('Tuần hoàn', Icons.favorite, AppColors.cardiovascular),
  lymphatic('Bạch huyết', Icons.bubble_chart, AppColors.lymphatic),
  nervous('Thần kinh', Icons.psychology, AppColors.nervous),
  respiratory('Hô hấp', Icons.air, AppColors.respiratory),
  digestive('Tiêu hóa', Icons.restaurant, AppColors.digestive),
  urinary('Tiết niệu', Icons.water_drop, AppColors.urinary),
  reproductive('Sinh dục', Icons.wc, AppColors.reproductive),
  endocrine('Nội tiết', Icons.science, AppColors.endocrine),
  sensory('Giác quan', Icons.visibility, AppColors.sensory),
  integumentary('Da', Icons.back_hand, AppColors.integumentary),
  other('Khác', Icons.more_horiz, AppColors.other);

  const BodySystem(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static BodySystem fromName(String name) =>
      BodySystem.values.firstWhere((s) => s.name == name, orElse: () => BodySystem.other);
}
