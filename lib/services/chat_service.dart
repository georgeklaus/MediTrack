import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _myUid => _auth.currentUser?.uid;

  /// Deterministic conversation ID — always the same for a given pair of users.
  String _convId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get or create the conversation document between the current user and [otherUid].
  /// Returns the conversation ID.
  Future<String> getOrCreateConversation({
    required String otherUid,
    required String otherName,
  }) async {
    final myUid = _myUid!;
    final myName = _auth.currentUser?.displayName ?? 'User';
    final convId = _convId(myUid, otherUid);
    final ref = _db.collection('conversations').doc(convId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'participants': [myUid, otherUid],
        'participantNames': {myUid: myName, otherUid: otherName},
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': '',
      });
    }
    return convId;
  }

  /// Stream all conversations for the current user, newest first.
  /// Sorts client-side to avoid requiring a composite Firestore index.
  Stream<List<ConversationModel>> conversationsStream() {
    final uid = _myUid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final list =
              snap.docs.map((doc) => ConversationModel.fromDoc(doc)).toList();
          list.sort((a, b) {
            final at = a.lastMessageTime ?? DateTime(0);
            final bt = b.lastMessageTime ?? DateTime(0);
            return bt.compareTo(at);
          });
          return list;
        });
  }

  /// Stream messages for a conversation, oldest first.
  Stream<List<MessageModel>> messagesStream(String convId) {
    return _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => MessageModel.fromDoc(doc)).toList());
  }

  /// Send a message and update conversation metadata atomically.
  /// [otherUid] is used to increment that user's unread counter.
  Future<void> sendMessage({
    required String convId,
    required String text,
    required String otherUid,
  }) async {
    final uid = _myUid;
    if (uid == null || text.trim().isEmpty) return;
    final trimmed = text.trim();
    final batch = _db.batch();

    final msgRef = _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'senderId': uid,
      'text': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [uid], // sender has already read their own message
    });

    batch.update(_db.collection('conversations').doc(convId), {
      'lastMessage': trimmed,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      // Increment the receiver's unread counter
      'unreadCounts.$otherUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Mark all messages sent by the other user as read by [myUid]
  /// and reset the unread counter on the conversation document.
  Future<void> markMessagesAsRead(String convId) async {
    final uid = _myUid;
    if (uid == null) return;
    final snap = await _db
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    bool hasUpdates = false;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['senderId'] == uid) continue; // skip own messages
      final readBy = List<String>.from(data['readBy'] as List? ?? []);
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
        hasUpdates = true;
      }
    }
    if (hasUpdates) await batch.commit();
    // Always reset our unread counter on the conversation doc so the
    // badge clears immediately (this write triggers the reactive stream).
    await _db.collection('conversations').doc(convId).update({
      'unreadCounts.$uid': 0,
    });
  }

  /// Stream the total number of unread messages across all conversations
  /// by reading the reactive `unreadCounts` field on each conversation doc.
  Stream<int> unreadChatCount() {
    final uid = _myUid;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
          int total = 0;
          for (final doc in snap.docs) {
            final counts =
                doc.data()['unreadCounts'] as Map<dynamic, dynamic>? ?? {};
            total += (counts[uid] as num?)?.toInt() ?? 0;
          }
          return total;
        });
  }
}
