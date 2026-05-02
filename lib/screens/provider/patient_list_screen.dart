import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/provider_service.dart';
import '../../theme/app_theme.dart';
import 'patient_details_screen.dart';

class PatientListScreen extends StatelessWidget {
  const PatientListScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text('My Patients',
                  style: Theme.of(context).textTheme.headlineLarge),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: providerService.patientsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  // Collect unique patients
                  final Map<String, Map<String, dynamic>> patients = {};
                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final pid = data['patientId'] as String?;
                    if (pid != null && !patients.containsKey(pid)) {
                      patients[pid] = data;
                    }
                  }
                  if (patients.isEmpty) {
                    return const Center(
                      child: Text('No patients yet.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: patients.length,
                    itemBuilder: (context, i) {
                      final pid = patients.keys.elementAt(i);
                      final data = patients[pid]!;
                      final lastApptTs = data['dateTime'] as Timestamp?;
                      final lastAppt = lastApptTs != null
                          ? DateFormat('MMM d, yyyy')
                              .format(lastApptTs.toDate())
                          : '—';
                      return _PatientCard(
                        patientId: pid,
                        patientName: data['patientName'] ?? 'Patient',
                        lastAppointment: lastAppt,
                        status: data['status'] ?? 'pending',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PatientDetailsScreen(patientId: pid),
                          ),
                        ),
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

class _PatientCard extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String lastAppointment;
  final String status;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patientId,
    required this.patientName,
    required this.lastAppointment,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Last visit: $lastAppointment',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
