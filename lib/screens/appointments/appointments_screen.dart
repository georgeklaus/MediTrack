import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/appointment_service.dart';
import '../../models/appointment_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/appointment_card.dart';
import 'book_appointment_screen.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid;
    final apptService = context.read<AppointmentService>();
    final now = DateTime.now();

    return DefaultTabController(
      length: 2,
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
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const BookAppointmentScreen()),
          ),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: uid == null
            ? const Center(child: Text('Not logged in'))
            : StreamBuilder<List<AppointmentModel>>(
                stream: apptService.getAppointments(uid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? [];
                  final upcoming = all
                      .where((a) => a.date.isAfter(now))
                      .toList()
                    ..sort((a, b) => a.date.compareTo(b.date));
                  final past = all
                      .where((a) => !a.date.isAfter(now))
                      .toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

                  return TabBarView(
                    children: [
                      _AppointmentList(
                        items: upcoming,
                        emptyMessage: 'No upcoming appointments',
                        onDelete: (id) async {
                          final confirmed = await _confirmDelete(ctx);
                          if (confirmed) await apptService.deleteAppointment(id);
                        },
                      ),
                      _AppointmentList(
                        items: past,
                        emptyMessage: 'No past appointments',
                        onDelete: (id) async {
                          final confirmed = await _confirmDelete(ctx);
                          if (confirmed) await apptService.deleteAppointment(id);
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Appointment'),
            content: const Text('Remove this appointment?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _AppointmentList extends StatelessWidget {
  final List<AppointmentModel> items;
  final String emptyMessage;
  final Future<void> Function(String id) onDelete;

  const _AppointmentList(
      {required this.items,
      required this.emptyMessage,
      required this.onDelete});

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
          doctorName: a.doctorName,
          date: a.date,
          notes: a.notes,
          onDelete: () => onDelete(a.id),
        );
      },
    );
  }
}
