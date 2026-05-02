import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final String providerId;
  final String patientName;
  final String providerName;
  final DateTime dateTime;
  final String reason;
  final String status; // pending | confirmed | completed | cancelled

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    required this.patientName,
    required this.providerName,
    required this.dateTime,
    this.reason = '',
    this.status = 'pending',
  });

  factory AppointmentModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return AppointmentModel(
      id: doc.id,
      patientId: map['patientId'] ?? map['userId'] ?? '',
      providerId: map['providerId'] ?? '',
      patientName: map['patientName'] ?? '',
      providerName: map['providerName'] ?? map['doctorName'] ?? '',
      dateTime: (map['dateTime'] as Timestamp?)?.toDate() ??
          (map['date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      reason: map['reason'] ?? map['notes'] ?? '',
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'providerId': providerId,
        'patientName': patientName,
        'providerName': providerName,
        'dateTime': Timestamp.fromDate(dateTime),
        'reason': reason,
        'status': status,
      };
}
