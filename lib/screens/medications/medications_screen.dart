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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Medications'),
          elevation: 0,
          backgroundColor: AppColors.background,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Prescribed'),
              Tab(text: 'My Medications'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'medications_fab',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
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
                  final all = snap.data ?? [];
                  final prescribed =
                      all.where((m) => m.source == 'doctor').toList();
                  final self =
                      all.where((m) => m.source != 'doctor').toList();

                  return TabBarView(
                    children: [
                      // ── Prescribed tab ──────────────────────────────
                      _MedList(
                        meds: prescribed,
                        medService: medService,
                        emptyIcon: Icons.local_hospital_outlined,
                        emptyTitle: 'No prescribed medications',
                        emptySubtitle:
                            'Medications prescribed by your doctor will appear here',
                        allowDelete: false,
                      ),
                      // ── My Medications tab ──────────────────────────
                      _MedList(
                        meds: self,
                        medService: medService,
                        emptyIcon: Icons.medication_outlined,
                        emptyTitle: 'No medications added',
                        emptySubtitle: 'Tap + to add your first medication',
                        allowDelete: true,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _MedList extends StatelessWidget {
  final List<MedicationModel> meds;
  final MedicationService medService;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool allowDelete;

  const _MedList({
    required this.meds,
    required this.medService,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.allowDelete,
  });

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

  @override
  Widget build(BuildContext context) {
    if (meds.isEmpty) {
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
              child: Icon(emptyIcon, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: meds.length,
      itemBuilder: (ctx, i) {
        final m = meds[i];
        return MedicationCard(
          name: m.name,
          form: m.form,
          dosage: m.dosage,
          frequency: m.frequency,
          duration: m.duration,
          source: m.source,
          prescribedBy: m.prescribedBy,
          time: m.time,
          onDelete: allowDelete
              ? () async {
                  final confirmed = await _confirmDelete(ctx, m.name);
                  if (confirmed) await medService.deleteMedication(m.id);
                }
              : null,
        );
      },
    );
  }
}

