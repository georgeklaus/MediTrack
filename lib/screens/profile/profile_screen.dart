import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../role_selection_screen.dart';
import 'account_information_screen.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF7B65F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        (user?.displayName?.isNotEmpty == true)
                            ? user!.displayName![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Settings tiles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _SettingsCard(children: [
                      _SettingsTile(
                        icon: Icons.person_outline,
                        title: 'Account Information',
                        subtitle: user?.email ?? '',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AccountInformationScreen()),
                        ),
                      ),
                      _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Medication & appointment reminders',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _SettingsCard(children: [
                      _SettingsTile(
                        icon: Icons.security_outlined,
                        title: 'Privacy & Security',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PrivacySecurityScreen()),
                        ),
                      ),
                      _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HelpSupportScreen()),
                        ),
                      ),
                      _SettingsDivider(),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: 'About MediTrack',
                        subtitle: 'Version 1.0.0',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // Sign out
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: ListTile(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16)),
                                  title: const Text('Sign Out'),
                                  content: const Text(
                                      'Are you sure you want to sign out?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Sign Out',
                                          style: TextStyle(
                                              color: AppColors.danger)),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (confirmed && context.mounted) {
                            await context.read<AuthService>().logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const RoleSelectionScreen()),
                                (route) => false,
                              );
                            }
                          }
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.logout,
                              color: AppColors.danger, size: 20),
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F0));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textSecondary, size: 18),
    );
  }
}
