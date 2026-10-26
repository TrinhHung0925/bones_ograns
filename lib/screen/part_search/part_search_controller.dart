import 'package:get/get.dart';

import '../../model/anatomy_part.dart';
import '../../service/anatomy_service.dart';

/// Searches parts by Vietnamese or English name (accents optional); pops
/// the chosen part as the route result.
class PartSearchController extends GetxController {
  final _anatomy = Get.find<AnatomyService>();

  final query = ''.obs;
  final results = <AnatomyPart>[].obs;

  @override
  void onInit() {
    super.onInit();
    debounce(query, (q) => results.assignAll(_anatomy.search(q)), time: const Duration(milliseconds: 150));
  }

  void onQueryChanged(String value) => query.value = value;

  void choose(AnatomyPart part) => Get.back(result: part);

  void onBack() {
    Get.back();
  }
}
