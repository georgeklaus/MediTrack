import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/appointment_model.dart';
import '../models/medical_note_model.dart';
import 'email_service.dart';

class AppointmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// All appointments for a patient, ordered by dateTime.
  Stream<List<AppointmentModel>> getAppointments(String patientId) {
    return _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => AppointmentModel.fromDoc(doc)).toList());
  }

  /// Book an appointment with a specific provider.
  /// Also writes a Firestore notification for the provider.
  Future<void> bookWithProvider({
    required String patientId,
    required String patientName,
    required String providerId,
    required String providerName,
    required DateTime dateTime,
    String reason = '',
  }) async {
    final ref = await _db.collection('appointments').add({
      'patientId': patientId,
      'providerId': providerId,
      'patientName': patientName,
      'providerName': providerName,
      'dateTime': Timestamp.fromDate(dateTime),
      'reason': reason,
      'status': 'pending',
    });

    // In-app notification for the provider
    await _db.collection('notifications').add({
      'recipientUid': providerId,
      'type': 'new_appointment',
      'message': '$patientName has requested an appointment',
      'read': false,
      'appointmentId': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Email notifications (non-blocking)
    final patientEmail = _auth.currentUser?.email ?? '';
    if (patientEmail.isNotEmpty) {
      EmailService.instance.sendAppointmentBooked(
        patientName: patientName,
        patientEmail: patientEmail,
        providerId: providerId,
        providerName: providerName,
        dateTime: dateTime,
        reason: reason,
      );
    }
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await _db
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'cancelled'});
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _db.collection('appointments').doc(appointmentId).delete();
  }

  /// Unread notification count for the current provider.
  Stream<int> unreadNotificationCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markAllNotificationsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Stream of all medical notes written by doctors for the current patient.
  Stream<List<MedicalNoteModel>> myMedicalNotesStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('medical_notes')
        .where('patientId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => MedicalNoteModel.fromDoc(doc)).toList());
  }
}
