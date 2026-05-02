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
    await _db.collection('appointments').doc(appointmentId).update({'status': status});
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
