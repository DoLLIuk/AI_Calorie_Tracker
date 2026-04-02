import 'package:flutter/material.dart';

enum MealType { breakfast, lunch, dinner, snack }

MealType classifyMealTypeByTime(DateTime time) {
  final minuteOfDay = (time.hour * 60) + time.minute;
  if (minuteOfDay >= 240 && minuteOfDay < 630) {
    return MealType.breakfast;
  }
  if (minuteOfDay >= 630 && minuteOfDay < 990) {
    return MealType.lunch;
  }
  if (minuteOfDay >= 990 && minuteOfDay < 1410) {
    return MealType.dinner;
  }
  return MealType.snack;
}

String mealTypeLabel(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return 'Breakfast';
    case MealType.lunch:
      return 'Lunch';
    case MealType.dinner:
      return 'Dinner';
    case MealType.snack:
      return 'Snack';
  }
}

IconData mealTypeIcon(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return Icons.free_breakfast_outlined;
    case MealType.lunch:
      return Icons.restaurant_outlined;
    case MealType.dinner:
      return Icons.nightlight_round;
    case MealType.snack:
      return Icons.apple_outlined;
  }
}
