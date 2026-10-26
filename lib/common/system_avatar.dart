import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../model/body_system.dart';

/// Round icon in the body system's colour.
class SystemAvatar extends StatelessWidget {
  const SystemAvatar({super.key, required this.system});

  final BodySystem system;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20.r,
      backgroundColor: system.color.withValues(alpha: 0.25),
      child: Icon(system.icon, color: system.color, size: 22.r),
    );
  }
}
