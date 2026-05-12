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
  /// Soft-deleted for everyone (sender action).
  final bool deleted;
  /// UIDs of users who chose "delete for me" — message hidden only for them.
  final List<String> deletedFor;
  /// ID of the message being quoted (reply).
  final String? replyToId;
  /// Preview text of the quoted message.
  final String? replyToText;
  /// Display name of the quoted message's sender.
  final String? replyToSenderName;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.readBy = const [],
    this.type = 'text',
    this.mediaUrl,
    this.fileName,
    this.deleted = false,
    this.deletedFor = const [],
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
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
      deleted: map['deleted'] as bool? ?? false,
      deletedFor: List<String>.from(map['deletedFor'] as List? ?? []),
      replyToId: map['replyToId'] as String?,
      replyToText: map['replyToText'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
    );
  }
}
