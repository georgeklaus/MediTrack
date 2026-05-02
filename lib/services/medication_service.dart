import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';

class MedicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<MedicationModel>> getMedications(String userId) {
    return _db
        .collection('medications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MedicationModel.fromDoc(doc))
            .toList());
  }

  Future<void> addMedication({
    required String userId,
    required String name,
    required String dosage,
    required DateTime time,
  }) async {
    await _db.collection('medications').add({
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'form': 'Tablet',
      'frequency': '',
      'duration': '',
      'source': 'self',
      'time': Timestamp.fromDate(time),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMedication(String medId) async {
    await _db.collection('medications').doc(medId).delete();
  }
}
