import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppointmentModel>> getAppointments(String userId) {
    return _db
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppointmentModel.fromDoc(doc))
            .toList());
  }

  Future<void> addAppointment({
    required String userId,
    required String doctorName,
    required DateTime date,
    String notes = '',
  }) async {
    final appt = AppointmentModel(
      id: '',
      userId: userId,
      doctorName: doctorName,
      date: date,
      notes: notes,
    );
    await _db.collection('appointments').add(appt.toMap());
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _db.collection('appointments').doc(appointmentId).delete();
  }
}
