import 'package:flutter/material.dart';

import '../onboarding.dart';
import 'profile_labels.dart';

class AccountSettingsPage extends StatefulWidget {
  final OnboardingResult? onboardingResult;
  final VoidCallback onLogout;
  final Future<void> Function() onEditProfile;

  const AccountSettingsPage({
    super.key,
    required this.onboardingResult,
    required this.onLogout,
    required this.onEditProfile,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool pushNotifications = true;
  bool twoFactor = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.onboardingResult;
    final userName = result == null
        ? 'Member'
        : '${sexLabel(result.sex)} Member';
    final subtitle = result == null
        ? 'Manage your personal health profile and preferences'
        : '${goalLabel(result.goalType)} | ${activityLabel(result.activityLevel)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F6),
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Account',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C3558),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8088A2),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    widget.onEditProfile();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C7AE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.face_rounded,
                            color: Color(0xFFB06B42),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF29324E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Premium member since 2025',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8A91A8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E6AF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Preferences'),
              _SettingsCard(
                child: _SettingsSwitchRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFF2E6AF5),
                  title: 'Push Notifications',
                  subtitle: 'Reminder at 9:00 AM and 6:15 PM',
                  value: pushNotifications,
                  onChanged: (value) =>
                      setState(() => pushNotifications = value),
                ),
              ),
              const SizedBox(height: 8),
              _SettingsCard(
                child: _SettingsChevronRow(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF8B4DE8),
                  title: 'Language',
                  subtitle: 'App localization',
                  value: 'English',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Security'),
              _SettingsCard(
                child: _SettingsChevronRow(
                  icon: Icons.lock_rounded,
                  iconColor: const Color(0xFFE36A6A),
                  title: 'Change Password',
                  subtitle: 'Last updated 5 months ago',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 8),
              _SettingsCard(
                child: _SettingsSwitchRow(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF2E6AF5),
                  title: 'Two-Factor Auth',
                  subtitle: 'Secure your health data',
                  value: twoFactor,
                  onChanged: (value) => setState(() => twoFactor = value),
                ),
              ),
              const SizedBox(height: 14),
              const _SettingsSectionTitle('Support'),
              _SettingsCard(
                child: _SettingsChevronRow(
                  icon: Icons.help_rounded,
                  iconColor: const Color(0xFFB58D36),
                  title: 'Help Center',
                  subtitle: 'FAQs and documentation',
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Подтверждение'),
                          content: const Text('Вы уверены, что хотите выйти?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Отмена'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD2212D),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Выйти'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed == true && context.mounted) {
                      Navigator.of(context).pop();
                      widget.onLogout();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 50),
                    backgroundColor: const Color(0xFFD2212D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'APP VERSION: 1.0.0 (1001)',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF9CA2B7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String label;

  const _SettingsSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFFA2A9BD),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBF2)),
      ),
      child: child,
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _SettingsIcon(icon: icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A3353),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A91A8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF2E6AF5),
            inactiveTrackColor: const Color(0xFFC6CDDD),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _SettingsChevronRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback onTap;

  const _SettingsChevronRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _SettingsIcon(icon: icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A3353),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8A91A8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7ECFF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  value!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF2E6AF5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8690AB),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
