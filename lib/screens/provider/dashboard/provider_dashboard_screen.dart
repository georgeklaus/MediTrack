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
              // ── Header ────────────────────────────────────────────────────
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

              // ── Stats row (all appointments stream) ───────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: providerService.appointmentsStream(),
                builder: (context, allSnap) {
                  final allDocs = allSnap.data?.docs ?? [];
                  final now = DateTime.now();
                  final startOfDay = DateTime(now.year, now.month, now.day);
                  final endOfDay = startOfDay.add(const Duration(days: 1));

                  final todayCount = allDocs.where((d) {
                    final ts = (d.data() as Map)['dateTime'] as Timestamp?;
                    final dt = ts?.toDate();
                    return dt != null &&
                        dt.isAfter(startOfDay) &&
                        dt.isBefore(endOfDay);
                  }).length;

                  final pendingCount = allDocs
                      .where((d) => (d.data() as Map)['status'] == 'pending')
                      .length;

                  final uniquePatients = allDocs
                      .map((d) => (d.data() as Map)['patientId'] as String?)
                      .whereType<String>()
                      .toSet()
                      .length;

                  return Column(
                    children: [
                      Row(
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
                              value: '$pendingCount',
                              icon: Icons.pending_actions,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Total\nPatients',
                              value: '$uniquePatients',
                              icon: Icons.people_outline,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Pending Requests ──────────────────────────────────────────
              _SectionHeader(title: 'Pending Requests', icon: Icons.pending_actions, color: AppColors.warning),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: providerService.appointmentsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pending = (snap.data?.docs ?? [])
                      .where((d) => (d.data() as Map)['status'] == 'pending')
                      .toList()
                    ..sort((a, b) {
                      final ta = ((a.data() as Map)['dateTime'] as Timestamp?)?.toDate();
                      final tb = ((b.data() as Map)['dateTime'] as Timestamp?)?.toDate();
                      if (ta == null || tb == null) return 0;
                      return ta.compareTo(tb);
                    });
                  if (pending.isEmpty) {
                    return const _EmptyCard(message: 'No pending requests.');
                  }
                  return Column(
                    children: pending.map((doc) => _AppointmentTile(
                      docId: doc.id,
                      data: doc.data() as Map<String, dynamic>,
                      providerService: providerService,
                      onPatientTap: (pid) => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: pid)),
                      ),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Today's Schedule ──────────────────────────────────────────
              _SectionHeader(title: "Today's Schedule", icon: Icons.today, color: AppColors.primary),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: providerService.todayAppointmentsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = (snap.data?.docs ?? [])
                    ..sort((a, b) {
                      final ta = ((a.data() as Map)['dateTime'] as Timestamp?)?.toDate();
                      final tb = ((b.data() as Map)['dateTime'] as Timestamp?)?.toDate();
                      if (ta == null || tb == null) return 0;
                      return ta.compareTo(tb);
                    });
                  if (docs.isEmpty) {
                    return const _EmptyCard(message: 'No appointments scheduled today.');
                  }
                  return Column(
                    children: docs.map((doc) => _AppointmentTile(
                      docId: doc.id,
                      data: doc.data() as Map<String, dynamic>,
                      providerService: providerService,
                      onPatientTap: (pid) => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: pid)),
                      ),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 28),

              // ── Upcoming (next 7 days, non-pending) ───────────────────────
              _SectionHeader(title: 'Upcoming This Week', icon: Icons.date_range, color: AppColors.success),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: providerService.appointmentsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final now = DateTime.now();
                  final endOfWeek = now.add(const Duration(days: 7));
                  final upcoming = (snap.data?.docs ?? []).where((d) {
                    final data = d.data() as Map;
                    final ts = data['dateTime'] as Timestamp?;
                    final dt = ts?.toDate();
                    final status = data['status'] as String? ?? '';
                    return dt != null &&
                        dt.isAfter(now) &&
                        dt.isBefore(endOfWeek) &&
                        status != 'cancelled' &&
                        status != 'pending';
                  }).toList()
                    ..sort((a, b) {
                      final ta = ((a.data() as Map)['dateTime'] as Timestamp?)?.toDate();
                      final tb = ((b.data() as Map)['dateTime'] as Timestamp?)?.toDate();
                      if (ta == null || tb == null) return 0;
                      return ta.compareTo(tb);
                    });
                  if (upcoming.isEmpty) {
                    return const _EmptyCard(message: 'No confirmed appointments this week.');
                  }
                  return Column(
                    children: upcoming.map((doc) => _AppointmentTile(
                      docId: doc.id,
                      data: doc.data() as Map<String, dynamic>,
                      providerService: providerService,
                      showDate: true,
                      onPatientTap: (pid) => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: pid)),
                      ),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
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

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ── Appointment tile ───────────────────────────────────────────────────────

class _AppointmentTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final ProviderService providerService;
  final void Function(String patientId) onPatientTap;
  final bool showDate;

  const _AppointmentTile({
    required this.docId,
    required this.data,
    required this.providerService,
    required this.onPatientTap,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final ts = data['dateTime'] as Timestamp?;
    final dt = ts?.toDate();
    final timeStr = dt != null
        ? showDate
            ? DateFormat('EEE, MMM d · h:mm a').format(dt)
            : DateFormat('h:mm a').format(dt)
        : '—';
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
            width: 44,
            height: 44,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => providerService.updateAppointmentStatus(docId, 'confirmed'),
                      child: const Text('Confirm',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => providerService.updateAppointmentStatus(docId, 'cancelled'),
                      child: const Text('Decline',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state card ───────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
