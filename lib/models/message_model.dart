import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final List<String> readBy;
  /// 'text' | 'image' | 'file'
  final String type;
  final String? mediaUrl;
  final String? fileName;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.readBy = const [],
    this.type = 'text',
    this.mediaUrl,
    this.fileName,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(map['readBy'] as List? ?? []),
      type: map['type'] as String? ?? 'text',
      mediaUrl: map['mediaUrl'] as String?,
      fileName: map['fileName'] as String?,
    );
  }
}
