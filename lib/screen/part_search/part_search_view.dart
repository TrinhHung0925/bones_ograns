import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../common/system_avatar.dart';
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
      appBar: AppBar(
        leading: BackButton(onPressed: controller.onBack),
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 16.sp),
          decoration: InputDecoration(
            hintText: AppText.searchHint,
            border: InputBorder.none,
          ),
          onChanged: controller.onQueryChanged,
        ),
      ),
      body: Obx(() {
        if (controller.query.value.trim().isEmpty) {
          return Center(child: Text(AppText.searchExample, style: TextStyle(fontSize: 14.sp)));
        }
        final results = controller.results;
        if (results.isEmpty) {
          return Center(child: Text(AppText.searchEmpty, style: TextStyle(fontSize: 14.sp)));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, i) {
            final part = results[i];
            return ListTile(
              leading: SystemAvatar(system: part.system),
              title: Text(part.name, style: TextStyle(fontSize: 16.sp)),
              subtitle: Text(part.system.label, style: TextStyle(fontSize: 13.sp)),
              onTap: () => controller.choose(part),
            );
          },
        );
      }),
    );
  }
}
