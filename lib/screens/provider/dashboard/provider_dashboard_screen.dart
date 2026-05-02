import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/provider_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../patient_details_screen.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final providerService = context.read<ProviderService>();
    final authService = context.read<AuthService>();
    final userName = authService.currentUser?.displayName ?? 'Doctor';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_greeting()},',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        Text(
                          'Dr. $userName',
                          style: Theme.of(context).textTheme.headlineLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services, color: AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats row
              StreamBuilder<QuerySnapshot>(
                stream: providerService.todayAppointmentsStream(),
                builder: (context, snap) {
                  final todayCount = snap.data?.docs.length ?? 0;
                  final pending = snap.data?.docs
                          .where((d) =>
                              (d.data() as Map)['status'] == 'pending')
                          .length ??
                      0;
                  return Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: "Today's\nAppointments",
                          value: '$todayCount',
                          icon: Icons.calendar_today,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Pending\nRequests',
                          value: '$pending',
                          icon: Icons.pending_actions,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Today's appointments
              Text("Today's Appointments",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: providerService.todayAppointmentsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _EmptyCard(message: 'No appointments today.');
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _AppointmentTile(
                        docId: doc.id,
                        data: data,
                        providerService: providerService,
                        onPatientTap: (patientId) =>
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PatientDetailsScreen(patientId: patientId),
                            )),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final ProviderService providerService;
  final void Function(String patientId) onPatientTap;

  const _AppointmentTile({
    required this.docId,
    required this.data,
    required this.providerService,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = data['dateTime'] as Timestamp?;
    final dt = ts?.toDate();
    final timeStr = dt != null ? DateFormat('h:mm a').format(dt) : '—';
    final patientName = data['patientName'] ?? 'Patient';
    final reason = data['reason'] ?? '';
    final status = data['status'] ?? 'pending';
    final patientId = data['patientId'] as String?;

    Color statusColor;
    switch (status) {
      case 'confirmed':
        statusColor = AppColors.success;
        break;
      case 'completed':
        statusColor = AppColors.info;
        break;
      case 'cancelled':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: patientId != null ? () => onPatientTap(patientId) : null,
                  child: Text(
                    patientName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (reason.isNotEmpty)
                  Text(reason,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                Text(timeStr,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => providerService.updateAppointmentStatus(
                      docId, 'confirmed'),
                  child: const Text('Confirm',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}
