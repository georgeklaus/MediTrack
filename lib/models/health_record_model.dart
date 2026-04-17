import 'package:cloud_firestore/cloud_firestore.dart';

class HealthRecordModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime date;

  HealthRecordModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.date,
  });

  factory HealthRecordModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return HealthRecordModel(
      id: doc.id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
      };
}
