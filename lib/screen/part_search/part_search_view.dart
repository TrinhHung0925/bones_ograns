import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/game_widgets.dart';
import '../../common/part_name.dart';
import '../../model/anatomy_part.dart';
import '../../resource/app_colors.dart';
import '../../resource/app_style.dart';
import '../../resource/app_text.dart';
import 'part_search_controller.dart';

class PartSearchView extends StatefulWidget {
  PartSearchView({super.key}) {
    if (!Get.isRegistered<PartSearchController>()) {
      Get.put(PartSearchController());
    }
  }

  @override
  State<PartSearchView> createState() => _PartSearchViewState();
}

class _PartSearchViewState extends State<PartSearchView> {
  var controller = Get.find<PartSearchController>();

  @override
  void dispose() {
    Get.delete<PartSearchController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameHeader(title: AppText.searchTitle, subtitle: AppText.searchSubtitle, onBack: controller.onBack),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _SearchField(onChanged: controller.onQueryChanged),
            ),
            SizedBox(height: 18.h),
            Expanded(
              child: Obx(() {
                if (controller.query.value.trim().isEmpty) {
                  return const _Message(icon: Icons.search_rounded, text: AppText.searchExample);
                }
                final results = controller.results;
                if (results.isEmpty) {
                  return const _Message(icon: Icons.search_off_rounded, text: AppText.searchEmpty);
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                  itemCount: results.length + 1,
                  separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 10.h),
                  itemBuilder: (context, i) {
                    if (i == 0) return SectionLabel(AppText.searchResults(results.length));
                    final part = results[i - 1];
                    return _ResultRow(part: part, onTap: () => controller.choose(part));
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chunky rounded search box.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      radius: 18,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.accent, size: 24.r),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: AppStyle.body(17, color: AppColors.textPrimary, weight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: AppText.searchHint,
                hintStyle: AppStyle.body(16, color: AppColors.textMuted),
                border: InputBorder.none,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.part, required this.onTap});

  final AnatomyPart part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      onTap: onTap,
      radius: 18,
      padding: EdgeInsets.all(12.r),
      child: Row(
        children: [
          IconBubble(icon: part.system.icon, color: part.system.color),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PartName(vi: part.displayName, en: part.name, style: AppStyle.title(17)),
                SizedBox(height: 4.h),
                Text(part.system.label, style: AppStyle.body(13, color: part.system.color)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 26.r),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 80.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBubble(icon: icon, color: AppColors.primary, size: 72),
            SizedBox(height: 14.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Text(text, textAlign: TextAlign.center, style: AppStyle.body(15)),
            ),
          ],
        ),
      ),
    );
  }
}
