import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String userId;
  final String doctorName;
  final DateTime date;
  final String notes;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.date,
    this.notes = '',
  });

  factory AppointmentModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      userId: map['userId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'doctorName': doctorName,
        'date': Timestamp.fromDate(date),
        'notes': notes,
      };
}
