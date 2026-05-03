import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String userId;
  final String name;         // original filename
  final String category;     // Lab Results, X-Ray, Prescription, Insurance, Other
  final String url;          // Firebase Storage download URL
  final String storagePath;  // path in Storage for deletion
  final String mimeType;     // image/jpeg, application/pdf, etc.
  final int sizeBytes;
  final DateTime uploadedAt;

  DocumentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.url,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory DocumentModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return DocumentModel(
      id: doc.id,
      userId: m['userId'] ?? '',
      name: m['name'] ?? '',
      category: m['category'] ?? 'Other',
      url: m['url'] ?? '',
      storagePath: m['storagePath'] ?? '',
      mimeType: m['mimeType'] ?? '',
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      uploadedAt:
          (m['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  bool get isImage =>
      mimeType.startsWith('image/');
}
