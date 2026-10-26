import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_text.dart';

class LoadingChip extends StatelessWidget {
  const LoadingChip({super.key, this.label = AppText.loadingModel});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: SizedBox.square(
        dimension: 16.r,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      label: Text(label, style: TextStyle(fontSize: 13.sp)),
    );
  }
}
