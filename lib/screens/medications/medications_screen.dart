import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/medication_service.dart';
import '../../models/medication_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/medication_card.dart';
import 'add_medication_screen.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid;
    final medService = context.read<MedicationService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Medications'),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'medications_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AddMedicationScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<List<MedicationModel>>(
              stream: medService.getMedications(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final meds = snap.data ?? [];
                if (meds.isEmpty) {
                  return _EmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: meds.length,
                  itemBuilder: (_, i) {
                    final m = meds[i];
                    return MedicationCard(
                      name: m.name,
                      dosage: m.dosage,
                      time: m.time,
                      onDelete: () async {
                        final confirmed = await _confirmDelete(ctx, m.name);
                        if (confirmed) {
                          await medService.deleteMedication(m.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Future<bool> _confirmDelete(BuildContext ctx, String name) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Medication'),
            content: Text('Remove "$name" from your list?'),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication_outlined,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('No medications yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Tap + to add your first medication',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
