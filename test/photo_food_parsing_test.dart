import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/photo_food/models.dart';

void main() {
  test('PhotoFoodResponse parsing', () {
    final json = {
      'request_id': 'req_123',
      'item': {
        'name': 'Chicken breast with rice',
        'category': 'main',
        'food_type': 'solid',
        'confidence': 0.87,
        'nutrition_per_100g': {
          'kcal': 165,
          'protein_g': 31,
          'fat_g': 3.6,
          'carbs_g': 0,
        },
        'warnings': ['LOW_CONFIDENCE'],
      },
      'ui_flags': {
        'requires_user_confirmation': true,
        'highlight_level': 'orange',
      },
      'meta': {
        'needs_confirmation': true,
        'estimated_portion_g': 180.0,
        'portion_basis': 'visual estimate',
        'confirmation_source': null,
        'totals_are_estimate': true,
        'estimated_totals': {
          'kcal': 297.0,
          'protein_g': 55.8,
          'fat_g': 6.5,
          'carbs_g': 0.0,
        },
      },
    };

    final response = PhotoFoodResponse.fromJson(json);

    expect(response.requestId, 'req_123');
    expect(response.item.name, 'Chicken breast with rice');
    expect(response.item.nutritionPer100g.kcal, 165);
    expect(response.uiFlags.requiresUserConfirmation, isTrue);
    expect(response.meta.estimatedPortionG, 180.0);
    expect(response.meta.totalsAreEstimate, isTrue);
    expect(response.meta.estimatedTotals?.kcal, 297.0);
  });
}
