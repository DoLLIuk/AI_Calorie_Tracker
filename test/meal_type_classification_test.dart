import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/meal_type.dart';

void main() {
  test('meal type classification by time boundaries', () {
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 3, 59)), MealType.snack);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 4, 0)), MealType.breakfast);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 10, 29)), MealType.breakfast);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 10, 30)), MealType.lunch);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 16, 29)), MealType.lunch);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 16, 30)), MealType.dinner);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 23, 29)), MealType.dinner);
    expect(classifyMealTypeByTime(DateTime(2026, 1, 1, 23, 30)), MealType.snack);
  });
}
