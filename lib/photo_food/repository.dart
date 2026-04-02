import 'package:image_picker/image_picker.dart';

import 'models.dart';

abstract class PhotoFoodRepository {
  Future<PhotoFoodResponse> analyzePhoto(
    XFile image, {
    String locale,
    String? mealTime,
  });

  Future<PhotoFoodResponse> confirmPortion({
    required String requestId,
    double? portionG,
    bool useAiEstimate = false,
  });
}
