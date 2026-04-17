import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationModel {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final DateTime time;
  final DateTime createdAt;

  MedicationModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.time,
    required this.createdAt,
  });

  factory MedicationModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MedicationModel(
      id: doc.id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      time: (map['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'dosage': dosage,
        'time': Timestamp.fromDate(time),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
