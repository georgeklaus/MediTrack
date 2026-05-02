import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalNoteModel {
  final String id;
  final String providerId;
  final String providerName;
  final String patientId;
  final String diagnosis;
  final String notes;
  final String prescription;
  final String followUp;
  final DateTime date;

  MedicalNoteModel({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.patientId,
    required this.diagnosis,
    required this.notes,
    required this.prescription,
    required this.followUp,
    required this.date,
  });

  factory MedicalNoteModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MedicalNoteModel(
      id: doc.id,
      providerId: map['providerId'] as String? ?? '',
      providerName: map['providerName'] as String? ?? 'Doctor',
      patientId: map['patientId'] as String? ?? '',
      diagnosis: map['diagnosis'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      prescription: map['prescription'] as String? ?? '',
      followUp: map['followUp'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
