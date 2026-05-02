import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationModel {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String form;           // Tablet, Capsule, Syrup, Injection, Cream, etc.
  final String frequency;      // Once daily, Twice daily, etc.
  final String duration;       // 3 days, 7 days, 1 month, etc.
  final String source;         // 'self' | 'doctor'
  final String? prescribedBy;  // Doctor name, only when source == 'doctor'
  final String? prescribedById;
  final DateTime? time;        // reminder time (self-added only)
  final DateTime createdAt;

  MedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.form,
    required this.frequency,
    required this.duration,
    required this.source,
    this.prescribedBy,
    this.prescribedById,
    this.time,
    required this.createdAt,
  });

  factory MedicationModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MedicationModel(
      id: doc.id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      form: map['form'] ?? 'Tablet',
      frequency: map['frequency'] ?? '',
      duration: map['duration'] ?? '',
      source: map['source'] ?? 'self',
      prescribedBy: map['prescribedBy'] as String?,
      prescribedById: map['prescribedById'] as String?,
      time: (map['time'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'dosage': dosage,
        'form': form,
        'frequency': frequency,
        'duration': duration,
        'source': source,
        if (prescribedBy != null) 'prescribedBy': prescribedBy,
        if (prescribedById != null) 'prescribedById': prescribedById,
        if (time != null) 'time': Timestamp.fromDate(time!),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
