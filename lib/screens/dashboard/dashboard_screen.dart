import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/medication_service.dart';
import '../../services/appointment_service.dart';
import '../../models/medication_model.dart';
import '../../models/appointment_model.dart';
import '../../theme/app_theme.dart';
import '../medications/medications_screen.dart';
import '../appointments/appointments_screen.dart';
import '../../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override

  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final medService = context.read<MedicationService>();
    final apptService = context.read<AppointmentService>();
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.displayName ?? 'User',
                          style: Theme.of(context).textTheme.headlineLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Today banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF7B65F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(now),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            DateFormat('MMMM d, yyyy').format(now),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Stay on track with your health today',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.health_and_safety,
                        color: Colors.white38, size: 60),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats row
              StreamBuilder<List<MedicationModel>>(
                stream: user != null
                    ? medService.getMedications(user.uid)
                    : const Stream.empty(),
                builder: (ctx, medSnap) {
                  return StreamBuilder<List<AppointmentModel>>(
                    stream: user != null
                        ? apptService.getAppointments(user.uid)
                        : const Stream.empty(),
                    builder: (ctx, apptSnap) {
                      final meds = medSnap.data?.length ?? 0;
                      final upcoming = apptSnap.data
                              ?.where((a) =>
                                  a.dateTime.isAfter(now) &&
                                  a.status != 'cancelled')
                              .length ??
                          0;
                      return Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Medications',
                              value: '$meds',
                              icon: Icons.medication,
                              color: AppColors.primary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const MedicationsScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Upcoming',
                              value: '$upcoming',
                              icon: Icons.calendar_today,
                              color: AppColors.accent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AppointmentsScreen()),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // Today's medications
              _SectionHeader(
                title: "Today's Medications",
                actionLabel: 'See all',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MedicationsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<MedicationModel>>(
                stream: user != null
                    ? medService.getMedications(user.uid)
                    : const Stream.empty(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final meds = snap.data ?? [];
                  if (meds.isEmpty) {
                    return _EmptyHint(
                      icon: Icons.medication_outlined,
                      message: 'No medications added yet',
                    );
                  }
                  final preview = meds.take(3).toList();
                  return Column(
                    children: preview
                        .map((m) => _MedTile(medication: m))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Upcoming appointments
              _SectionHeader(
                title: 'Upcoming Appointments',
                actionLabel: 'See all',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<AppointmentModel>>(
                stream: user != null
                    ? apptService.getAppointments(user.uid)
                    : const Stream.empty(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final appts = (snap.data ?? [])
                      .where((a) =>
                          a.dateTime.isAfter(now) &&
                          a.status != 'cancelled')
                      .take(3)
                      .toList();
                  if (appts.isEmpty) {
                    return _EmptyHint(
                      icon: Icons.calendar_today_outlined,
                      message: 'No upcoming appointments',
                    );
                  }
                  return Column(
                    children: appts.map((a) => _ApptTile(appt: a)).toList(),
                  );
                },
              ),
              const SizedBox(height: 80), // bottom nav clearance
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader(
      {required this.title,
      required this.actionLabel,
      required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.withValues(alpha: 0.5), size: 40),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MedTile extends StatelessWidget {
  final MedicationModel medication;
  const _MedTile({required this.medication});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medication.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                Text(medication.dosage,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            medication.time != null
                ? DateFormat('h:mm a').format(medication.time!)
                : medication.frequency.isNotEmpty
                    ? medication.frequency
                    : '',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _ApptTile extends StatelessWidget {
  final AppointmentModel appt;
  const _ApptTile({required this.appt});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'completed':
        return AppColors.info;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today,
                color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    appt.providerName.isNotEmpty
                        ? 'Dr. ${appt.providerName}'
                        : 'Doctor',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                Text(
                    DateFormat('EEE, MMM d • h:mm a').format(appt.dateTime),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(appt.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              appt.status[0].toUpperCase() + appt.status.substring(1),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(appt.status)),
            ),
          ),
        ],
      ),
    );
  }
}
