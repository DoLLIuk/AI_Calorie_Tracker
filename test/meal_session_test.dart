import 'package:flutter_test/flutter_test.dart';
import 'package:my_new_app/meal_session.dart';
import 'package:my_new_app/meal_type.dart';

void main() {
  const service = MealSessionService();

  MealSessionEntry buildEntry({
    required String id,
    required DateTime timestamp,
    required double kcal,
    MealType? userSelectedType,
  }) {
    return MealSessionEntry(
      id: id,
      timestamp: timestamp,
      name: id,
      kcal: kcal,
      proteinG: kcal / 20,
      fatG: kcal / 30,
      carbsG: kcal / 10,
      userSelectedSessionType: userSelectedType,
    );
  }

  test('groups with rolling 15-minute window', () {
    final day = DateTime(2026, 3, 8);
    final sessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2000,
      entries: [
        buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 13, 0), kcal: 120),
        buildEntry(id: 'b', timestamp: DateTime(2026, 3, 8, 13, 10), kcal: 80),
        buildEntry(id: 'c', timestamp: DateTime(2026, 3, 8, 13, 18), kcal: 150),
        buildEntry(id: 'd', timestamp: DateTime(2026, 3, 8, 13, 28), kcal: 90),
        buildEntry(id: 'e', timestamp: DateTime(2026, 3, 8, 13, 50), kcal: 250),
      ],
    );

    expect(sessions.length, 2);
    expect(sessions[0].entries.length, 1);
    expect(sessions[1].entries.length, 4);
  });

  test('classifies low-calorie lunch window as lunch extra', () {
    final day = DateTime(2026, 3, 8);
    final sessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2000,
      entries: [
        buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 13, 5), kcal: 80),
        buildEntry(id: 'b', timestamp: DateTime(2026, 3, 8, 13, 12), kcal: 100),
      ],
    );

    expect(sessions.single.totalKcal, 180);
    expect(sessions.single.autoDetectedType, MealType.lunch);
    expect(sessions.single.autoDetectedTier, MealSessionTier.extra);
    expect(sessions.single.finalType, MealType.lunch);
  });

  test('classifies high-calorie lunch window as lunch', () {
    final day = DateTime(2026, 3, 8);
    final sessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2000,
      entries: [
        buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 13, 5), kcal: 250),
        buildEntry(id: 'b', timestamp: DateTime(2026, 3, 8, 13, 12), kcal: 260),
      ],
    );

    expect(sessions.single.totalKcal, 510);
    expect(sessions.single.autoDetectedType, MealType.lunch);
  });

  test('classifies 380 kcal in lunch window as lunch for high daily target due cap', () {
    final day = DateTime(2026, 3, 8);
    final sessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2400,
      entries: [
        buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 14, 51), kcal: 380),
      ],
    );

    expect(sessions.single.autoDetectedType, MealType.lunch);
  });

  test('classifies outside main windows as snack', () {
    final day = DateTime(2026, 3, 8);
    final sessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2400,
      entries: [
        buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 1, 20), kcal: 380),
      ],
    );

    expect(sessions.single.autoDetectedType, MealType.snack);
  });

  test('threshold caps stay at breakfast 300, lunch 350, dinner 400', () {
    final thresholds = MealSessionThresholds.fromDailyTarget(4000);
    expect(thresholds.breakfast, 300);
    expect(thresholds.lunch, 350);
    expect(thresholds.dinner, 400);
  });

  test('supports multiple sessions with same type in one day', () {
    final day = DateTime(2026, 3, 8);
    final sessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2000,
      entries: [
        buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 12, 0), kcal: 400),
        buildEntry(id: 'b', timestamp: DateTime(2026, 3, 8, 14, 0), kcal: 420),
      ],
    );

    expect(sessions.length, 2);
    expect(sessions[0].finalType, MealType.lunch);
    expect(sessions[1].finalType, MealType.lunch);
  });

  test('manual override sets final type and survives recompute', () {
    final day = DateTime(2026, 3, 8);
    final baseEntries = [
      buildEntry(id: 'a', timestamp: DateTime(2026, 3, 8, 13, 0), kcal: 260),
      buildEntry(id: 'b', timestamp: DateTime(2026, 3, 8, 13, 10), kcal: 220),
    ];

    final autoSessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2000,
      entries: baseEntries,
    );
    expect(autoSessions.single.autoDetectedType, MealType.lunch);

    final overriddenSessions = service.buildSessionsForDay(
      day: day,
      dailyCalorieTarget: 2000,
      entries: [
        buildEntry(
          id: 'a',
          timestamp: DateTime(2026, 3, 8, 13, 0),
          kcal: 260,
          userSelectedType: MealType.dinner,
        ),
        buildEntry(id: 'b', timestamp: DateTime(2026, 3, 8, 13, 10), kcal: 220),
      ],
    );

    expect(overriddenSessions.single.overriddenByUser, isTrue);
    expect(overriddenSessions.single.autoDetectedType, MealType.lunch);
    expect(overriddenSessions.single.finalType, MealType.dinner);
  });
}
