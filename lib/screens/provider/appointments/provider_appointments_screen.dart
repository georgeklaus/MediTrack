import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../services/provider_service.dart';
import '../../../theme/app_theme.dart';
import '../patient_details_screen.dart';

class ProviderAppointmentsScreen extends StatefulWidget {
  const ProviderAppointmentsScreen({super.key});

  @override
  State<ProviderAppointmentsScreen> createState() =>
      _ProviderAppointmentsScreenState();
}

class _ProviderAppointmentsScreenState
    extends State<ProviderAppointmentsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final providerService = context.read<ProviderService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('Appointments',
                  style: Theme.of(context).textTheme.headlineLarge),
            ),
            const SizedBox(height: 12),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final f in ['all', 'pending', 'confirmed', 'completed', 'cancelled'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f[0].toUpperCase() + f.substring(1)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _filter == f ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: providerService.appointmentsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snap.data?.docs ?? [];
                  if (_filter != 'all') {
                    docs = docs
                        .where((d) =>
                            (d.data() as Map)['status'] == _filter)
                        .toList();
                  }
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No appointments found.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      return _AppointmentCard(
                        docId: doc.id,
                        data: data,
                        providerService: providerService,
                        onPatientTap: (pid) =>
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PatientDetailsScreen(patientId: pid),
                            )),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final ProviderService providerService;
  final void Function(String) onPatientTap;

  const _AppointmentCard({
    required this.docId,
    required this.data,
    required this.providerService,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    final ts = data['dateTime'] as Timestamp?;
    final dt = ts?.toDate();
    final dateStr =
        dt != null ? DateFormat('EEE, MMM d · h:mm a').format(dt) : '—';
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: patientId != null ? () => onPatientTap(patientId) : null,
                child: Text(patientName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(dateStr,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reason: $reason',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          if (status == 'pending' || status == 'confirmed') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'pending')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => providerService
                          .updateAppointmentStatus(docId, 'confirmed'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success)),
                      child: const Text('Confirm'),
                    ),
                  ),
                if (status == 'pending') const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => providerService
                        .updateAppointmentStatus(docId, 'completed'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('Mark Complete'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
