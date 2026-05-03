import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';

class DocumentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Stream of all documents for the current user, newest first.
  Stream<List<DocumentModel>> documentsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('documents')
        .where('userId', isEqualTo: uid)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DocumentModel.fromDoc(d)).toList());
  }

  /// Upload a file to Firebase Storage and save metadata to Firestore.
  /// Returns a stream of upload progress (0.0 – 1.0).
  Stream<double> uploadDocument({
    required File file,
    required String fileName,
    required String category,
    required String mimeType,
  }) async* {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final storagePath =
        'documents/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(contentType: mimeType);
    final uploadTask = ref.putFile(file, metadata);

    await for (final snap in uploadTask.snapshotEvents) {
      final total = snap.totalBytes;
      final transferred = snap.bytesTransferred;
      if (total > 0) yield transferred / total;

      if (snap.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        final fileSize = file.lengthSync();
        await _db.collection('documents').add({
          'userId': uid,
          'name': fileName,
          'category': category,
          'url': url,
          'storagePath': storagePath,
          'mimeType': mimeType,
          'sizeBytes': fileSize,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
        yield 1.0;
      }
    }
  }

  /// Delete document from both Storage and Firestore.
  Future<void> deleteDocument(DocumentModel doc) async {
    // Delete from Storage (ignore error if file already gone)
    try {
      await _storage.ref().child(doc.storagePath).delete();
    } catch (_) {}
    await _db.collection('documents').doc(doc.id).delete();
  }
}
