import 'meal_type.dart';

const Duration mealSessionGap = Duration(minutes: 15);

class MealSessionThresholds {
  final double breakfast;
  final double lunch;
  final double dinner;

  const MealSessionThresholds({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  factory MealSessionThresholds.fromDailyTarget(double dailyCalorieTarget) {
    return MealSessionThresholds(
      breakfast: _clampMinMax(dailyCalorieTarget * 0.10, 220, 300),
      lunch: _clampMinMax(dailyCalorieTarget * 0.18, 350, 350),
      dinner: _clampMinMax(dailyCalorieTarget * 0.20, 400, 400),
    );
  }

  double forMealType(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return breakfast;
      case MealType.lunch:
        return lunch;
      case MealType.dinner:
        return dinner;
      case MealType.snack:
        return double.infinity;
    }
  }

  static double _clampMinMax(double value, double minValue, double maxValue) {
    final withMin = value < minValue ? minValue : value;
    return withMin > maxValue ? maxValue : withMin;
  }
}

class MealSessionEntry {
  final String id;
  final DateTime timestamp;
  final String name;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final MealType? userSelectedSessionType;

  const MealSessionEntry({
    required this.id,
    required this.timestamp,
    required this.name,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    this.userSelectedSessionType,
  });
}

class MealSession {
  final String id;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final List<MealSessionEntry> entries;
  final double totalKcal;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final MealType autoDetectedType;
  final MealType finalType;
  final MealSessionTier autoDetectedTier;
  final MealSessionTier finalTier;
  final bool overriddenByUser;

  const MealSession({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.entries,
    required this.totalKcal,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.autoDetectedType,
    required this.finalType,
    required this.autoDetectedTier,
    required this.finalTier,
    required this.overriddenByUser,
  });
}

enum MealSessionTier { mainMeal, extra }

MealType classifyMainMealByStartTime(DateTime startTime) {
  final minuteOfDay = (startTime.hour * 60) + startTime.minute;
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

MealType classifySessionAutoType({
  required DateTime startTime,
  required double totalKcal,
  required double dailyCalorieTarget,
}) {
  final candidateMeal = classifyMainMealByStartTime(startTime);
  if (candidateMeal == MealType.snack) {
    return MealType.snack;
  }
  // Inside a main meal window, keep the category in that window.
  return candidateMeal;
}

MealSessionTier classifySessionTierForType({
  required MealType type,
  required double totalKcal,
  required double dailyCalorieTarget,
}) {
  if (type == MealType.snack) {
    return MealSessionTier.extra;
  }
  final thresholds = MealSessionThresholds.fromDailyTarget(dailyCalorieTarget);
  final threshold = thresholds.forMealType(type);
  if (totalKcal < threshold) {
    return MealSessionTier.extra;
  }
  return MealSessionTier.mainMeal;
}

class MealSessionService {
  const MealSessionService();

  List<MealSession> buildSessionsForDay({
    required DateTime day,
    required List<MealSessionEntry> entries,
    required double dailyCalorieTarget,
  }) {
    if (entries.isEmpty) return const [];

    final sortedEntries = List<MealSessionEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sessions = <MealSession>[];
    var bucket = <MealSessionEntry>[sortedEntries.first];

    for (var i = 1; i < sortedEntries.length; i++) {
      final next = sortedEntries[i];
      final gap = next.timestamp.difference(bucket.last.timestamp);
      if (gap <= mealSessionGap) {
        bucket.add(next);
      } else {
        sessions.add(_buildSingleSession(day: day, entries: bucket, dailyCalorieTarget: dailyCalorieTarget));
        bucket = <MealSessionEntry>[next];
      }
    }

    sessions.add(_buildSingleSession(day: day, entries: bucket, dailyCalorieTarget: dailyCalorieTarget));
    return sessions.reversed.toList(growable: false);
  }

  MealSession _buildSingleSession({
    required DateTime day,
    required List<MealSessionEntry> entries,
    required double dailyCalorieTarget,
  }) {
    final sorted = List<MealSessionEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final start = sorted.first.timestamp;
    final end = sorted.last.timestamp;
    final totalKcal = sorted.fold(0.0, (sum, e) => sum + e.kcal);
    final totalProtein = sorted.fold(0.0, (sum, e) => sum + e.proteinG);
    final totalFat = sorted.fold(0.0, (sum, e) => sum + e.fatG);
    final totalCarbs = sorted.fold(0.0, (sum, e) => sum + e.carbsG);
    final autoType = classifySessionAutoType(
      startTime: start,
      totalKcal: totalKcal,
      dailyCalorieTarget: dailyCalorieTarget,
    );
    final autoTier = classifySessionTierForType(
      type: autoType,
      totalKcal: totalKcal,
      dailyCalorieTarget: dailyCalorieTarget,
    );

    MealType? overrideType;
    for (final entry in sorted.reversed) {
      if (entry.userSelectedSessionType != null) {
        overrideType = entry.userSelectedSessionType;
        break;
      }
    }

    final overriddenByUser = overrideType != null;
    final finalType = overrideType ?? autoType;
    final finalTier = overriddenByUser
        ? classifySessionTierForType(
            type: finalType,
            totalKcal: totalKcal,
            dailyCalorieTarget: dailyCalorieTarget,
          )
        : autoTier;

    return MealSession(
      id: _sessionId(day: day, start: start, end: end),
      date: DateTime(day.year, day.month, day.day),
      startTime: start,
      endTime: end,
      entries: sorted,
      totalKcal: totalKcal,
      totalProtein: totalProtein,
      totalFat: totalFat,
      totalCarbs: totalCarbs,
      autoDetectedType: autoType,
      finalType: finalType,
      autoDetectedTier: autoTier,
      finalTier: finalTier,
      overriddenByUser: overriddenByUser,
    );
  }

  String _sessionId({
    required DateTime day,
    required DateTime start,
    required DateTime end,
  }) {
    final dayPart = '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final startPart = '${start.hour.toString().padLeft(2, '0')}${start.minute.toString().padLeft(2, '0')}';
    final endPart = '${end.hour.toString().padLeft(2, '0')}${end.minute.toString().padLeft(2, '0')}';
    return 'session_${dayPart}_${startPart}_$endPart';
  }
}
