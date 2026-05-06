import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/document_model.dart';

// ---------------------------------------------------------------------------
// Cloudinary config (unsigned upload — no secret required)
// ---------------------------------------------------------------------------
const _cloudName   = 'drhvwmzrg';
const _uploadPreset = 'Meditrack-proj';

class DocumentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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

  /// Upload a file to Cloudinary and save metadata to Firestore.
  /// Yields progress values 0.0 – 1.0 (Cloudinary doesn't support streaming
  /// progress, so we yield 0.5 while uploading then 1.0 on completion).
  Stream<double> uploadDocument({
    required File file,
    required String fileName,
    required String category,
    required String mimeType,
  }) async* {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    yield 0.1;

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'meditrack/$uid'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        // contentType not strictly required for unsigned uploads
      ));

    yield 0.3;

    final streamedResponse = await request.send();

    yield 0.8;

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $responseBody');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final url       = json['secure_url'] as String;
    final publicId  = json['public_id'] as String;
    final fileBytes = (json['bytes'] as num?)?.toInt() ?? file.lengthSync();

    await _db.collection('documents').add({
      'userId':     uid,
      'name':       fileName,
      'category':   category,
      'url':        url,
      'storagePath': publicId,   // Cloudinary public_id stored for reference
      'mimeType':   mimeType,
      'sizeBytes':  fileBytes,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    yield 1.0;
  }

  /// Delete document record from Firestore.
  /// (Cloudinary files are kept — deletion requires a signed API call
  /// which should be done via a backend/Cloud Function in production.)
  Future<void> deleteDocument(DocumentModel doc) async {
    await _db.collection('documents').doc(doc.id).delete();
  }
}

