import '../onboarding.dart';

String sexLabel(SexType sex) {
  switch (sex) {
    case SexType.male:
      return 'Male';
    case SexType.female:
      return 'Female';
  }
}

String goalLabel(GoalType goal) {
  switch (goal) {
    case GoalType.loseWeight:
      return 'Lose fat';
    case GoalType.maintain:
      return 'Maintain';
    case GoalType.gainWeight:
      return 'Gain muscle';
    case GoalType.trackOnly:
      return 'Just track';
  }
}

String activityLabel(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 'Sedentary';
    case ActivityLevel.lightlyActive:
      return 'Lightly active';
    case ActivityLevel.moderatelyActive:
      return 'Moderately active';
    case ActivityLevel.veryActive:
      return 'Very active';
    case ActivityLevel.athlete:
      return 'Very active';
  }
}
