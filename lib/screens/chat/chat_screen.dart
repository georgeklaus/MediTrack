import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';

const _cloudName = 'drhvwmzrg';
const _uploadPreset = 'Meditrack-proj';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _uploading = false;
  Timer? _typingTimer;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    ChatService.instance.markMessagesAsRead(widget.conversationId);
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    ChatService.instance.setTyping(widget.conversationId, false);
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textCtrl.text.isNotEmpty;
    ChatService.instance.setTyping(widget.conversationId, hasText);
    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        ChatService.instance.setTyping(widget.conversationId, false);
      });
    }
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    _typingTimer?.cancel();
    ChatService.instance.setTyping(widget.conversationId, false);
    try {
      await ChatService.instance.sendMessage(
        convId: widget.conversationId,
        text: text,
        otherUid: widget.otherUserId,
      );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSend() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image_outlined,
                    color: AppColors.primary),
              ),
              title: const Text('Photo'),
              subtitle: const Text('Send an image from your gallery'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.attach_file, color: AppColors.primary),
              ),
              title: const Text('File'),
              subtitle: const Text('Send a document or any file'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    File? file;
    String fileName = '';
    String type = 'file';

    try {
      if (choice == 'photo') {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (picked == null) return;
        file = File(picked.path);
        fileName = picked.name;
        type = 'image';
      } else {
        final result = await FilePicker.platform.pickFiles(withData: false);
        if (result == null || result.files.isEmpty) return;
        final pf = result.files.first;
        if (pf.path == null) return;
        file = File(pf.path!);
        fileName = pf.name;
        type = 'file';
      }
    } catch (_) {
      return;
    }

    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final mediaUrl = await _uploadToCloudinary(file, fileName);
      await ChatService.instance.sendMessage(
        convId: widget.conversationId,
        text: type == 'image' ? '📷 Photo' : fileName,
        otherUid: widget.otherUserId,
        type: type,
        mediaUrl: mediaUrl,
        fileName: fileName,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String> _uploadToCloudinary(File file, String fileName) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
      ));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('Upload failed (${streamed.statusCode})');
    }
    return json.decode(body)['secure_url'] as String;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.otherUserName,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white)),
                  // ── Typing indicator ────────────────────────────────
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: ChatService.instance
                        .conversationStream(widget.conversationId),
                    builder: (ctx, snap) {
                      final typingUid =
                          snap.data?.data()?['typingUid'] as String? ?? '';
                      if (typingUid == widget.otherUserId) {
                        return const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('typing',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic)),
                            SizedBox(width: 3),
                            _TypingDots(),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Message list ──────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: ChatService.instance
                      .messagesStream(widget.conversationId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snap.data ?? [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text('No messages yet.\nSay hello!',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }
                    // Auto-scroll + mark as read on new messages
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                      if (mounted) {
                        ChatService.instance
                            .markMessagesAsRead(widget.conversationId);
                      }
                    });
                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        final isMe = msg.senderId == _myUid;
                        // Show date separator when day changes
                        final showDate = i == 0 ||
                            !_sameDay(
                                messages[i - 1].timestamp, msg.timestamp);
                        return Column(
                          children: [
                            if (showDate) _DateSeparator(msg.timestamp),
                            _MessageBubble(
                              msg: msg,
                              isMe: isMe,
                              otherUserId: widget.otherUserId,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Input bar ─────────────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Attachment button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _uploading ? null : _pickAndSend,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: _uploading
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _sending ? null : _send,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.send,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Upload progress overlay ────────────────────────────────────
          if (_uploading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Uploading…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Typing dots animation ────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
            final opacity = (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2)
                .clamp(0.2, 1.0);
            return Opacity(
              opacity: opacity,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 1),
                child: Text('•',
                    style:
                        TextStyle(fontSize: 12, color: Colors.white70)),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final String otherUserId;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.otherUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = msg.type == 'image';
    final isFile = msg.type == 'file';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage && msg.mediaUrl != null)
              _ImageContent(url: msg.mediaUrl!, isMe: isMe)
            else if (isFile && msg.mediaUrl != null)
              _FileContent(
                url: msg.mediaUrl!,
                fileName: msg.fileName ?? 'File',
                isMe: isMe,
              )
            else
              Text(
                msg.text,
                style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 14.5),
              ),
            const SizedBox(height: 3),
            Padding(
              padding: isImage
                  ? const EdgeInsets.only(right: 6, bottom: 4)
                  : EdgeInsets.zero,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.timestamp),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    _TickIcon(isRead: msg.readBy.contains(otherUserId)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image content ────────────────────────────────────────────────────────
class _ImageContent extends StatelessWidget {
  final String url;
  final bool isMe;
  const _ImageContent({required this.url, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          width: 200,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, prog) {
            if (prog == null) return child;
            return SizedBox(
              width: 200,
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  value: prog.expectedTotalBytes != null
                      ? prog.cumulativeBytesLoaded /
                          prog.expectedTotalBytes!
                      : null,
                  color: isMe ? Colors.white : AppColors.primary,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.broken_image, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}

// ── File content ─────────────────────────────────────────────────────────
class _FileContent extends StatelessWidget {
  final String url;
  final String fileName;
  final bool isMe;
  const _FileContent(
      {required this.url, required this.fileName, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            color: isMe ? Colors.white70 : AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Tap to open',
                  style: TextStyle(
                    color: isMe ? Colors.white60 : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Date separator ─────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator(this.date);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year && date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ── Tick icon (read receipts) ──────────────────────────────────────────────
class _TickIcon extends StatelessWidget {
  final bool isRead;
  const _TickIcon({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return isRead
        ? const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent)
        : const Icon(Icons.done, size: 14, color: Colors.white60);
  }
}
