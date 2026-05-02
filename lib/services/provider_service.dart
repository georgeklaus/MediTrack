import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/provider_model.dart';

class ProviderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Future<ProviderModel?> getProviderProfile() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return ProviderModel.fromDoc(doc);
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? specialization,
    String? facility,
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (specialization != null) data['specialization'] = specialization;
    if (facility != null) data['facility'] = facility;
    await _db.collection('users').doc(uid).update(data);
  }

  /// Returns all appointments for this provider.
  Stream<QuerySnapshot> appointmentsStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('appointments')
        .where('providerId', isEqualTo: uid)
        .orderBy('dateTime', descending: false)
        .snapshots();
  }

  /// Returns today's appointments.
  Stream<QuerySnapshot> todayAppointmentsStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _db
        .collection('appointments')
        .where('providerId', isEqualTo: uid)
        .where('dateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    // Update status
    await _db
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': status});

    // Notify the patient
    final apptDoc =
        await _db.collection('appointments').doc(appointmentId).get();
    final apptData = apptDoc.data();
    if (apptData == null) return;
    final patientId = apptData['patientId'] as String?;
    if (patientId == null) return;

    // Fetch provider name
    final providerDoc = await _db.collection('users').doc(currentUid).get();
    final providerData = providerDoc.data();
    final providerName = providerData?['name'] as String? ?? 'Your doctor';

    String message;
    switch (status) {
      case 'confirmed':
        message = 'Dr. $providerName has confirmed your appointment.';
        break;
      case 'completed':
        message = 'Your appointment with Dr. $providerName is marked as completed.';
        break;
      case 'cancelled':
        message = 'Dr. $providerName has declined your appointment request.';
        break;
      default:
        message = 'Your appointment status has been updated to $status.';
    }

    await _db.collection('notifications').add({
      'recipientUid': patientId,
      'type': 'appointment_update',
      'message': message,
      'read': false,
      'appointmentId': appointmentId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns unique patients who have appointments with this provider.
  Stream<QuerySnapshot> patientsStream() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('appointments')
        .where('providerId', isEqualTo: uid)
        .snapshots();
  }

  Future<DocumentSnapshot> getPatientProfile(String patientId) {
    return _db.collection('users').doc(patientId).get();
  }

  Stream<QuerySnapshot> patientAppointmentsStream(String patientId) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('appointments')
        .where('providerId', isEqualTo: uid)
        .where('patientId', isEqualTo: patientId)
        .orderBy('dateTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> patientNotesStream(String patientId) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('medical_notes')
        .where('providerId', isEqualTo: uid)
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> addMedicalNote({
    required String patientId,
    required String diagnosis,
    required String notes,
    required String prescription,
    required String followUp,
    required DateTime visitDate,
    List<Map<String, String>> medications = const [],
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    // Fetch provider's display name to store alongside the note
    final providerDoc = await _db.collection('users').doc(uid).get();
    final data = providerDoc.data();
    final providerName = data?['name'] as String? ?? 'Doctor';
    await _db.collection('medical_notes').add({
      'providerId': uid,
      'providerName': providerName,
      'patientId': patientId,
      'diagnosis': diagnosis,
      'notes': notes,
      'prescription': prescription,
      'followUp': followUp,
      'date': Timestamp.fromDate(visitDate),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Write prescribed medications to the patient's medications collection
    if (medications.isNotEmpty) {
      final batch = _db.batch();
      for (final med in medications) {
        final ref = _db.collection('medications').doc();
        batch.set(ref, {
          'userId': patientId,
          'name': med['name'] ?? '',
          'form': med['form'] ?? 'Tablet',
          'dosage': med['dosage'] ?? '',
          'frequency': med['frequency'] ?? '',
          'duration': med['duration'] ?? '',
          'source': 'doctor',
          'prescribedBy': providerName,
          'prescribedById': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// Availability is stored per provider.
  Future<Map<String, dynamic>?> getAvailability() async {
    final uid = currentUid;
    if (uid == null) return null;
    final doc = await _db.collection('availability').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> saveAvailability(Map<String, dynamic> data) async {
    final uid = currentUid;
    if (uid == null) return;
    await _db.collection('availability').doc(uid).set(data, SetOptions(merge: true));
  }
}
