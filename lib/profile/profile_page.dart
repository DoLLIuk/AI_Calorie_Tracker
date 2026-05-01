import 'dart:math';

import 'package:flutter/material.dart';

import '../onboarding.dart';
import 'account_settings_page.dart';
import 'profile_labels.dart';

class ProfilePage extends StatelessWidget {
  final OnboardingResult? onboardingResult;
  final VoidCallback onResetOnboarding;
  final Future<void> Function() onEditProfile;

  const ProfilePage({
    super.key,
    this.onboardingResult,
    required this.onResetOnboarding,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final result = onboardingResult;
    final calorieTarget = result?.plan.calorieTarget ?? 2000;
    final proteinTarget = result?.plan.proteinTargetG ?? 150;
    final fatTarget = result?.plan.fatTargetG ?? 60;
    final carbsTarget = result?.plan.carbsTargetG ?? 220;

    final ageValue = result?.age.toString() ?? '--';
    final heightValue = result == null
        ? '--'
        : '${result.heightCm.toStringAsFixed(0)} cm';
    final weightValue = result == null
        ? '--'
        : '${result.weightKg.toStringAsFixed(1)} kg';

    final bmi = result == null
        ? null
        : result.weightKg / pow(result.heightCm / 100, 2);
    final bmiValue = bmi == null ? '--' : bmi.toStringAsFixed(1);

    final trendKg = switch (result?.goalType) {
      GoalType.loseWeight => -1.2,
      GoalType.gainWeight => 1.1,
      GoalType.maintain || GoalType.trackOnly || null => 0.0,
    };
    final trendLabel = trendKg > 0
        ? '+${trendKg.toStringAsFixed(1)}kg'
        : '${trendKg.toStringAsFixed(1)}kg';
    final trendCaption = trendKg == 0 ? 'steady this week' : 'this week';

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lumina Health',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF20243A),
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD5DAE6)),
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Color(0xFF2F66F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE9E7EE),
                      border: Border.all(
                        color: const Color(0xFFD9DFEE),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.phone_iphone_rounded,
                      size: 44,
                      color: Color(0xFFFFA377),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () {
                        onEditProfile();
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2F66F6),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                result == null
                    ? 'Your Profile'
                    : '${sexLabel(result.sex)} Profile',
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222A44),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _ProfileChip(
                    label: result == null
                        ? 'GOAL'
                        : goalLabel(result.goalType).toUpperCase(),
                  ),
                  _ProfileChip(
                    label: result == null
                        ? 'ACTIVITY'
                        : activityLabel(result.activityLevel).toUpperCase(),
                    bg: const Color(0xFFD7DBE8),
                    textColor: const Color(0xFF4F5978),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ProfileMetricCard(
                  title: 'Age',
                  value: ageValue,
                  valueColor: const Color(0xFF2B66F6),
                ),
                _ProfileMetricCard(
                  title: 'Height',
                  value: heightValue,
                  valueColor: const Color(0xFF2B66F6),
                ),
                _ProfileMetricCard(
                  title: 'Weight',
                  value: weightValue,
                  valueColor: const Color(0xFF25A55F),
                ),
                _ProfileMetricCard(
                  title: 'BMI',
                  value: bmiValue,
                  valueColor: const Color(0xFFE5793A),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EBF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Consistency',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2B3045),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          'weight trend over last 7 days',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF76809C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        trendLabel,
                        style: const TextStyle(
                          fontSize: 34,
                          color: Color(0xFF2F66F6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      trendCaption,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9DA5BC),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _WeeklyBars(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Badges & Streaks',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF283151),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(
                  child: _BadgeCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Color(0xFFFF9A33),
                    title: '3-DAY STREAK',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _BadgeCard(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: Color(0xFF2F66F6),
                    title: 'PROTEIN MASTER',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _BadgeCard(
                    icon: Icons.verified_user_rounded,
                    iconColor: Color(0xFF3AA35B),
                    title: 'WEIGHT HERO',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Daily Targets',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF283151),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9EBF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories Target',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$calorieTarget kcal',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111322),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: 0,
                        backgroundColor: Color(0xFFD7D9DE),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF111322),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$calorieTarget kcal left',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7E8293),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroCard(
                          title: 'Protein',
                          amount: '0g',
                          amountColor: const Color(0xFF2B66F6),
                          goal: 'of ${proteinTarget}g',
                          left: '${proteinTarget}g left',
                          value: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MacroCard(
                          title: 'Carbs',
                          amount: '0g',
                          amountColor: const Color(0xFFE5793A),
                          goal: 'of ${carbsTarget}g',
                          left: '${carbsTarget}g left',
                          value: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MacroCard(
                          title: 'Fats',
                          amount: '0g',
                          amountColor: const Color(0xFF25A55F),
                          goal: 'of ${fatTarget}g',
                          left: '${fatTarget}g left',
                          value: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AccountSettingsPage(
                      onboardingResult: result,
                      onLogout: onResetOnboarding,
                      onEditProfile: onEditProfile,
                    ),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.settings, size: 17, color: Color(0xFF606A84)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'App Preferences',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF293252),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 19,
                      color: Color(0xFF606A84),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('reset-onboarding-btn'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFFD2212D),
                  minimumSize: const Size.fromHeight(56),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: onResetOnboarding,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_circle_filled_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'RESET ONBOARDING',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _ProfileChip({
    required this.label,
    this.bg = const Color(0xFFAEC2F7),
    this.textColor = const Color(0xFF2D4A9E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 38) / 2,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: 0,
                backgroundColor: Color(0xFFD7D9DE),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111322)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars();

  @override
  Widget build(BuildContext context) {
    const bars = [0.30, 0.70, 0.45, 0.78, 0.52, 0.88, 0.62];
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 7,
                        height: 66 * bars[index],
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F95D8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF8D95AD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _BadgeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF576180),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color amountColor;
  final String goal;
  final String left;
  final double value;

  const _MacroCard({
    required this.title,
    required this.amount,
    required this.amountColor,
    required this.goal,
    required this.left,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: amountColor,
            ),
          ),
          Text(
            goal,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: const Color(0xFFD7D9DE),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF111322),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            left,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7E8293)),
          ),
        ],
      ),
    );
  }
}
