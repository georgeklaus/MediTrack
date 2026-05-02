import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/provider_service.dart';
import '../../theme/app_theme.dart';

// Per-medication entry controllers
class _MedEntry {
  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final durationCtrl = TextEditingController();
  String form = 'Tablet';
  String frequency = 'Once daily';

  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    durationCtrl.dispose();
  }
}

class AddMedicalNoteScreen extends StatefulWidget {
  final String patientId;

  const AddMedicalNoteScreen({super.key, required this.patientId});

  @override
  State<AddMedicalNoteScreen> createState() => _AddMedicalNoteScreenState();
}

class _AddMedicalNoteScreenState extends State<AddMedicalNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _prescriptionCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();
  DateTime _visitDate = DateTime.now();
  bool _loading = false;

  bool _showMedications = false;
  final List<_MedEntry> _meds = [];

  static const _formOptions = [
    'Tablet', 'Capsule', 'Syrup', 'Injection', 'Cream', 'Drops', 'Inhaler',
  ];
  static const _freqOptions = [
    'Once daily', 'Twice daily', 'Three times daily', 'Four times daily',
    'Every 6 hours', 'Every 8 hours', 'Every 12 hours',
    'As needed', 'Before meals', 'After meals', 'At bedtime',
  ];

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    _prescriptionCtrl.dispose();
    _followUpCtrl.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _visitDate = picked);
  }

  void _addMedEntry() {
    setState(() => _meds.add(_MedEntry()));
  }

  void _removeMedEntry(int index) {
    setState(() {
      _meds[index].dispose();
      _meds.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Collect medications
      final meds = _meds
          .where((m) => m.nameCtrl.text.trim().isNotEmpty)
          .map((m) => {
                'name': m.nameCtrl.text.trim(),
                'form': m.form,
                'dosage': m.dosageCtrl.text.trim(),
                'frequency': m.frequency,
                'duration': m.durationCtrl.text.trim(),
              })
          .toList();

      await context.read<ProviderService>().addMedicalNote(
            patientId: widget.patientId,
            diagnosis: _diagnosisCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            prescription: _prescriptionCtrl.text.trim(),
            followUp: _followUpCtrl.text.trim(),
            visitDate: _visitDate,
            medications: meds,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(meds.isNotEmpty
                ? 'Note saved with ${meds.length} medication(s).'
                : 'Medical note saved.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medical Note')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visit date picker
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Visit Date: ${_visitDate.day}/${_visitDate.month}/${_visitDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.edit,
                            size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _diagnosisCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Diagnosis',
                    prefixIcon: Icon(Icons.medical_information_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter diagnosis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  textInputAction: TextInputAction.next,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Clinical Notes',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prescriptionCtrl,
                  textInputAction: TextInputAction.next,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Prescription',
                    prefixIcon: Icon(Icons.medication_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _followUpCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Instructions',
                    prefixIcon: Icon(Icons.next_plan_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Medications toggle ───────────────────────────────────
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showMedications = !_showMedications;
                      if (_showMedications && _meds.isEmpty) _addMedEntry();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _showMedications
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showMedications
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medication,
                            color: _showMedications
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Prescribe Medications',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _showMedications
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (_showMedications && _meds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_meds.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          _showMedications
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showMedications) ...[
                  const SizedBox(height: 12),
                  ..._meds.asMap().entries.map((entry) {
                    final i = entry.key;
                    final med = entry.value;
                    return _MedEntryCard(
                      index: i,
                      entry: med,
                      formOptions: _formOptions,
                      freqOptions: _freqOptions,
                      onRemove: () => _removeMedEntry(i),
                      onChanged: () => setState(() {}),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addMedEntry,
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.primary),
                    label: const Text('Add Another Medication',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],

                const SizedBox(height: 28),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Medical Note'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single medication entry card ──────────────────────────────────────────

class _MedEntryCard extends StatelessWidget {
  final int index;
  final _MedEntry entry;
  final List<String> formOptions;
  final List<String> freqOptions;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _MedEntryCard({
    required this.index,
    required this.entry,
    required this.formOptions,
    required this.freqOptions,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Medication ${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 13),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: entry.nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Medicine Name *',
              prefixIcon: Icon(Icons.medication_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: entry.form,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Form', isDense: true),
                  items: formOptions
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      entry.form = v;
                      onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: entry.dosageCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g. 500mg)',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: entry.frequency,
            isDense: true,
            decoration:
                const InputDecoration(labelText: 'Frequency', isDense: true),
            items: freqOptions
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                entry.frequency = v;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: entry.durationCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Duration (e.g. 7 days, 2 weeks)',
              prefixIcon: Icon(Icons.timelapse_outlined),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

