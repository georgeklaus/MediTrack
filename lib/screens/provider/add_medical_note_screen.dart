import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/provider_service.dart';
import '../../theme/app_theme.dart';

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

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _notesCtrl.dispose();
    _prescriptionCtrl.dispose();
    _followUpCtrl.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<ProviderService>().addMedicalNote(
            patientId: widget.patientId,
            diagnosis: _diagnosisCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            prescription: _prescriptionCtrl.text.trim(),
            followUp: _followUpCtrl.text.trim(),
            visitDate: _visitDate,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical note saved.')),
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
                        const Icon(Icons.edit, size: 16,
                            color: AppColors.textSecondary),
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
