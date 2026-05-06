import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/provider_service.dart';
import '../../theme/app_theme.dart';
import 'add_medical_note_screen.dart';
import 'provider_documents_screen.dart';

class PatientDetailsScreen extends StatelessWidget {
  final String patientId;

  const PatientDetailsScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final providerService = context.read<ProviderService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Patient Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: 'Add Medical Note',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddMedicalNoteScreen(patientId: patientId),
            )),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: providerService.getPatientProfile(patientId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? 'Patient';
          final email = data['email'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient profile card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            if (email.isNotEmpty)
                              Text(email,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddMedicalNoteScreen(patientId: patientId))),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Add Note'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ProviderDocumentsScreen(
                                    patientId: patientId,
                                    patientName: name))),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Files'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Appointment history
                Text('Appointment History',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: providerService.patientAppointmentsStream(patientId),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _emptyCard('No appointments found.');
                    }
                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final ts = d['dateTime'] as Timestamp?;
                        final dt = ts?.toDate();
                        final dateStr = dt != null
                            ? DateFormat('EEE, MMM d, yyyy · h:mm a').format(dt)
                            : '—';
                        final status = d['status'] ?? 'pending';
                        return _infoTile(
                          title: dateStr,
                          subtitle: 'Status: $status',
                          icon: Icons.calendar_today,
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Medical notes
                Text('Medical Notes',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: providerService.patientNotesStream(patientId),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _emptyCard('No medical notes yet.');
                    }
                    return Column(
                      children: docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final ts = d['date'] as Timestamp?;
                        final dt = ts?.toDate();
                        final dateStr = dt != null
                            ? DateFormat('MMM d, yyyy').format(dt)
                            : '—';
                        return _NoteCard(data: d, dateStr: dateStr);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _infoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String dateStr;

  const _NoteCard({required this.data, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text('Visit: $dateStr',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const Divider(height: 16),
          if ((data['diagnosis'] ?? '').isNotEmpty)
            _row('Diagnosis', data['diagnosis']),
          if ((data['notes'] ?? '').isNotEmpty) _row('Notes', data['notes']),
          if ((data['prescription'] ?? '').isNotEmpty)
            _row('Prescription', data['prescription']),
          if ((data['followUp'] ?? '').isNotEmpty)
            _row('Follow-up', data['followUp']),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
