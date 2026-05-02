import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/appointment_service.dart';
import '../../theme/app_theme.dart';
import 'dashboard/provider_dashboard_screen.dart';
import 'appointments/provider_appointments_screen.dart';
import 'patient_list_screen.dart';
import 'availability_screen.dart';
import 'provider_profile_screen.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ProviderDashboardScreen(),
    ProviderAppointmentsScreen(),
    PatientListScreen(),
    ProviderAvailabilityScreen(),
    ProviderProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final apptService = context.read<AppointmentService>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                StreamBuilder<int>(
                  stream: apptService.unreadNotificationCount(),
                  builder: (context, snap) {
                    final count = snap.data ?? 0;
                    return _NavItem(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      label: 'Appointments',
                      isActive: _currentIndex == 1,
                      badge: count > 0 ? count : null,
                      onTap: () {
                        setState(() => _currentIndex = 1);
                        if (count > 0) apptService.markAllNotificationsRead();
                      },
                    );
                  },
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Patients',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.schedule_outlined,
                  activeIcon: Icons.schedule,
                  label: 'Availability',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isActive: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.accent : AppColors.textSecondary,
                size: 24,
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
