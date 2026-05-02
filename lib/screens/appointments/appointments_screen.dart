import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/appointment_service.dart';
import '../../models/appointment_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/appointment_card.dart';
import 'find_doctor_screen.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid;
    final apptService = context.read<AppointmentService>();
    final now = DateTime.now();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Appointments'),
          backgroundColor: AppColors.background,
          elevation: 0,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
              Tab(text: 'Find Doctor'),
            ],
          ),
        ),
        body: uid == null
            ? const Center(child: Text('Not logged in'))
            : TabBarView(
                children: [
                  // ── Upcoming ──────────────────────────────────────────────
                  StreamBuilder<List<AppointmentModel>>(
                    stream: apptService.getAppointments(uid),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final upcoming = (snap.data ?? [])
                          .where((a) =>
                              a.dateTime.isAfter(now) &&
                              a.status != 'cancelled')
                          .toList()
                        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                      return _AppointmentList(
                        items: upcoming,
                        emptyMessage: 'No upcoming appointments.\nTap "Find Doctor" to book one.',
                        apptService: apptService,
                      );
                    },
                  ),
                  // ── Past ──────────────────────────────────────────────────
                  StreamBuilder<List<AppointmentModel>>(
                    stream: apptService.getAppointments(uid),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final past = (snap.data ?? [])
                          .where((a) =>
                              !a.dateTime.isAfter(now) ||
                              a.status == 'cancelled' ||
                              a.status == 'completed')
                          .toList()
                        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
                      return _AppointmentList(
                        items: past,
                        emptyMessage: 'No past appointments.',
                        apptService: apptService,
                        isPast: true,
                      );
                    },
                  ),
                  // ── Find Doctor ───────────────────────────────────────────
                  const FindDoctorScreen(),
                ],
              ),
      ),
    );
  }
}

class _AppointmentList extends StatelessWidget {
  final List<AppointmentModel> items;
  final String emptyMessage;
  final AppointmentService apptService;
  final bool isPast;

  const _AppointmentList({
    required this.items,
    required this.emptyMessage,
    required this.apptService,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text(emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        return AppointmentCard(
          doctorName: a.providerName.isNotEmpty
              ? 'Dr. ${a.providerName}'
              : 'Doctor',
          date: a.dateTime,
          notes: a.reason,
          status: a.status,
          onCancel: (!isPast && a.status != 'cancelled')
              ? () async {
                  final confirmed = await _confirmCancel(context);
                  if (confirmed) await apptService.cancelAppointment(a.id);
                }
              : null,
        );
      },
    );
  }

  Future<bool> _confirmCancel(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Cancel Appointment'),
            content: const Text('Are you sure you want to cancel this appointment?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('No')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Cancel',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ) ??
        false;
  }
}


