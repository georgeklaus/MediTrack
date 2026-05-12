import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  /// Per-user unread count. Key = uid, value = number of unread messages.
  final Map<String, int> unreadCounts;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.participantNames,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCounts = const {},
  });

  factory ConversationModel.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final participants = List<String>.from(map['participants'] ?? []);
    final rawNames = map['participantNames'] as Map<dynamic, dynamic>? ?? {};
    final participantNames = rawNames.map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    final rawCounts = map['unreadCounts'] as Map<dynamic, dynamic>? ?? {};
    final unreadCounts = rawCounts.map(
      (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
    );
    return ConversationModel(
      id: doc.id,
      participants: participants,
      participantNames: participantNames,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastSenderId: map['lastSenderId'] as String?,
      unreadCounts: unreadCounts,
    );
  }

  String otherParticipantId(String myUid) =>
      participants.firstWhere((id) => id != myUid, orElse: () => '');

  String otherParticipantName(String myUid) {
    final otherId = otherParticipantId(myUid);
    return participantNames[otherId] ?? 'Unknown';
  }
}
