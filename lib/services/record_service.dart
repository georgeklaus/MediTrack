import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_record_model.dart';

class RecordService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<HealthRecordModel>> getRecords(String userId) {
    return _db
        .collection('records')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => HealthRecordModel.fromDoc(doc))
            .toList());
  }

  Future<void> addRecord({
    required String userId,
    required String title,
    required String description,
    required DateTime date,
  }) async {
    final record = HealthRecordModel(
      id: '',
      userId: userId,
      title: title,
      description: description,
      date: date,
    );
    await _db.collection('records').add(record.toMap());
  }

  Future<void> deleteRecord(String recordId) async {
    await _db.collection('records').doc(recordId).delete();
  }
}
