import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Future<String> _getRole(String uid) async {
    if (uid.isEmpty) return 'patient';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return (doc.data()?['role'] as String?) ?? 'patient';
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _getRole(myUid),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final isProvider = roleSnap.data == 'provider';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('Messages',
                      style: Theme.of(context).textTheme.headlineLarge),
                ),
                Expanded(
                  child: _ContactsView(myUid: myUid, isProvider: isProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Role-aware contacts list ───────────────────────────────────────────────
class _ContactsView extends StatelessWidget {
  final String myUid;
  final bool isProvider;

  const _ContactsView({required this.myUid, required this.isProvider});

  Stream<List<_Contact>> _providerPatients() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('providerId', isEqualTo: myUid)
        .snapshots()
        .map((snap) {
          final Map<String, _Contact> seen = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final uid = data['patientId'] as String?;
            final name = data['patientName'] as String?;
            if (uid != null && uid.isNotEmpty && name != null &&
                !seen.containsKey(uid)) {
              seen[uid] = _Contact(uid: uid, name: name);
            }
          }
          return seen.values.toList();
        });
  }

  Stream<List<_Contact>> _patientProviders() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: myUid)
        .snapshots()
        .map((snap) {
          final Map<String, _Contact> seen = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final uid = data['providerId'] as String?;
            final raw = data['providerName'] as String?;
            if (uid != null && uid.isNotEmpty && raw != null &&
                !seen.containsKey(uid)) {
              final name = raw.startsWith('Dr.') ? raw : 'Dr. $raw';
              seen[uid] = _Contact(uid: uid, name: name);
            }
          }
          return seen.values.toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    final contactsStream =
        isProvider ? _providerPatients() : _patientProviders();

    return StreamBuilder<List<_Contact>>(
      stream: contactsStream,
      builder: (context, contactsSnap) {
        if (contactsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final contacts = contactsSnap.data ?? [];
        if (contacts.isEmpty) {
          return _EmptyState(isProvider: isProvider);
        }

        return StreamBuilder<List<ConversationModel>>(
          stream: ChatService.instance.conversationsStream(),
          builder: (context, convSnap) {
            final convsByOther = <String, ConversationModel>{
              for (final c in convSnap.data ?? [])
                c.otherParticipantId(myUid): c,
            };

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: contacts.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1),
              itemBuilder: (context, i) {
                final contact = contacts[i];
                final conv = convsByOther[contact.uid];
                return _ContactTile(
                  myUid: myUid,
                  contact: contact,
                  conversation: conv,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Contact tile ───────────────────────────────────────────────────────────
class _ContactTile extends StatelessWidget {
  final String myUid;
  final _Contact contact;
  final ConversationModel? conversation;

  const _ContactTile({
    required this.myUid,
    required this.contact,
    this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = conversation?.lastMessage ?? '';
    final time = conversation?.lastMessageTime;
    final timeStr = time == null
        ? ''
        : DateTime.now().difference(time).inDays == 0
            ? DateFormat('HH:mm').format(time)
            : DateFormat('MMM d').format(time);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(contact.name,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        lastMsg.isEmpty ? 'Tap to start chatting' : lastMsg,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: lastMsg.isEmpty
              ? AppColors.primary.withValues(alpha: 0.6)
              : AppColors.textSecondary,
          fontSize: 13,
          fontStyle: lastMsg.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      trailing: timeStr.isNotEmpty
          ? Text(timeStr,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12))
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () async {
        final convId = await ChatService.instance.getOrCreateConversation(
          otherUid: contact.uid,
          otherName: contact.name,
        );
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: convId,
                otherUserId: contact.uid,
                otherUserName: contact.name,
              ),
            ),
          );
        }
      },
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isProvider;
  const _EmptyState({required this.isProvider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No conversations yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            isProvider
                ? 'Your patients will appear here\nonce they book appointments.'
                : 'Book an appointment to start\nmessaging your doctor.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Simple data class ──────────────────────────────────────────────────────
class _Contact {
  final String uid;
  final String name;
  const _Contact({required this.uid, required this.name});
}
