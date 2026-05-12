import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
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

/// Minimal data carried when the user swipes to reply.
class _ReplyPreview {
  final String id;
  final String senderName;
  final String text;
  const _ReplyPreview(
      {required this.id, required this.senderName, required this.text});
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _textFocusNode = FocusNode();
  bool _sending = false;
  bool _uploading = false;
  Timer? _typingTimer;
  _ReplyPreview? _replyTo;
  // Cached streams — created once so they're never recreated on rebuild
  late final Stream<List<MessageModel>> _messagesStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _convStream;
  // GlobalKey per message id — used for scroll-to-quoted-message
  final Map<String, GlobalKey> _msgKeys = {};
  String? _highlightedMsgId;
  // Track last seen message count to guard auto-scroll
  int _lastMsgCount = 0;
  // Latest messages snapshot — updated directly (no setState) for scroll-to
  List<MessageModel> _messages = [];
  // Scroll-to-bottom FAB — ValueNotifier so scroll never triggers a setState
  final _showFabNotifier = ValueNotifier<bool>(false);
  final _unreadNotifier = ValueNotifier<int>(0);

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// True if the scroll position is near the bottom (within 200 px).
  bool get _isNearBottom {
    if (!_scrollCtrl.hasClients) return true;
    final pos = _scrollCtrl.position;
    return pos.maxScrollExtent - pos.pixels < 200;
  }

  @override
  void initState() {
    super.initState();
    // Cache streams here — if created inside build() a new stream is made on
    // every rebuild, causing StreamBuilder to briefly flash a loading spinner.
    _messagesStream =
        ChatService.instance.messagesStream(widget.conversationId);
    _convStream =
        ChatService.instance.conversationStream(widget.conversationId);
    ChatService.instance.markMessagesAsRead(widget.conversationId);
    _textCtrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = !_isNearBottom;
    if (shouldShow != _showFabNotifier.value) {
      _showFabNotifier.value = shouldShow;
      if (!shouldShow) _unreadNotifier.value = 0;
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    ChatService.instance.setTyping(widget.conversationId, false);
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _textFocusNode.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _showFabNotifier.dispose();
    _unreadNotifier.dispose();
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

  void _setReply(_ReplyPreview? reply) => setState(() => _replyTo = reply);

  /// Scroll to a message by ID and briefly highlight it.
  /// Phase 1: if widget is already visible, use ensureVisible directly.
  /// Phase 2: otherwise estimate position, scroll there, then refine.
  Future<void> _scrollToMessage(String msgId) async {
    // Phase 1 — already on screen?
    final key = _msgKeys[msgId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    } else {
      // Phase 2 — estimate proportional offset and scroll there
      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx < 0) return;
      if (_scrollCtrl.hasClients) {
        final total = _scrollCtrl.position.maxScrollExtent;
        final frac = _messages.length > 1 ? idx / (_messages.length - 1) : 0.0;
        await _scrollCtrl.animateTo(
          frac * total,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      // Wait for the list to build the newly visible items
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      // Phase 2b — refine with ensureVisible now that item may be mounted
      final key2 = _msgKeys[msgId];
      if (key2?.currentContext != null) {
        await Scrollable.ensureVisible(
          key2!.currentContext!,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      }
    }
    if (!mounted) return;
    setState(() => _highlightedMsgId = msgId);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _highlightedMsgId = null);
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final reply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    _textCtrl.clear();
    _typingTimer?.cancel();
    ChatService.instance.setTyping(widget.conversationId, false);
    try {
      await ChatService.instance.sendMessage(
        convId: widget.conversationId,
        text: text,
        otherUid: widget.otherUserId,
        replyToId: reply?.id,
        replyToText: reply?.text,
        replyToSenderName: reply?.senderName,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open picker: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final reply = _replyTo;
      if (mounted) setState(() => _replyTo = null);
      final mediaUrl = await _uploadToCloudinary(file, fileName);
      await ChatService.instance.sendMessage(
        convId: widget.conversationId,
        text: type == 'image' ? '📷 Photo' : fileName,
        otherUid: widget.otherUserId,
        type: type,
        mediaUrl: mediaUrl,
        fileName: fileName,
        replyToId: reply?.id,
        replyToText: reply?.text,
        replyToSenderName: reply?.senderName,
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
                    stream: _convStream,
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
                child: Stack(children: [
                StreamBuilder<List<MessageModel>>(
                  stream: _messagesStream,
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
                    // Update snapshot reference (no setState — avoids rebuild)
                    _messages = messages;

                    // Only auto-scroll + mark-read when NEW messages arrive,
                    // not on every parent setState (send/reply/highlight etc.)
                    if (messages.length > _lastMsgCount) {
                      final newCount = messages.length - _lastMsgCount;
                      _lastMsgCount = messages.length;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_isNearBottom) {
                          _scrollToBottom();
                        } else {
                          _unreadNotifier.value += newCount;
                        }
                        if (mounted) {
                          ChatService.instance
                              .markMessagesAsRead(widget.conversationId);
                        }
                      });
                    }
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
                        // Use ValueKey (not GlobalKey) as the list-item key
                        // so Flutter reconciles by value without element moves.
                        // A zero-height SizedBox carries the GlobalKey for ensureVisible.
                        _msgKeys[msg.id] ??= GlobalKey();
                        return Column(
                          key: ValueKey(msg.id),
                          children: [
                            if (showDate) _DateSeparator(msg.timestamp),
                            SizedBox(key: _msgKeys[msg.id], height: 0),
                            _SwipeToReply(
                                onReply: () {
                                  final hiddenForMe = msg.deleted ||
                                      msg.deletedFor.contains(_myUid);
                                  if (hiddenForMe) return;
                                  final senderName = isMe
                                      ? 'You'
                                      : widget.otherUserName;
                                  final preview = msg.type == 'image'
                                      ? '📷 Photo'
                                      : msg.type == 'file'
                                          ? '📎 ${msg.fileName ?? 'File'}'
                                          : msg.text;
                                  _setReply(_ReplyPreview(
                                    id: msg.id,
                                    senderName: senderName,
                                    text: preview,
                                  ));
                                  _textFocusNode.requestFocus();
                                },
                                child: _MessageBubble(
                                  msg: msg,
                                  isMe: isMe,
                                  myUid: _myUid,
                                  otherUserId: widget.otherUserId,
                                  convId: widget.conversationId,
                                  highlighted: _highlightedMsgId == msg.id,
                                  onTapReplyQuote: msg.replyToId != null
                                      ? () => _scrollToMessage(msg.replyToId!)
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showFabNotifier,
                    builder: (_, show, __) {
                      if (!show) return const SizedBox.shrink();
                      return ValueListenableBuilder<int>(
                        valueListenable: _unreadNotifier,
                        builder: (_, unread, __) => _ScrollFab(
                          unread: unread,
                          onTap: () {
                            _scrollToBottom();
                            _unreadNotifier.value = 0;
                          },
                        ),
                      );
                    },
                  ),
                ),
                ])),

              // ── Reply preview bar ──────────────────────────────────────
              if (_replyTo != null)
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _replyTo!.senderName,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _replyTo!.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _setReply(null),
                      ),
                    ],
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
                          focusNode: _textFocusNode,
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

// ── Swipe-to-reply wrapper ────────────────────────────────────────────────
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReply({required this.child, required this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  static const _threshold = 60.0;
  bool _triggered = false;

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (d.delta.dx < 0) return; // only right swipe
    setState(() {
      _dragOffset = (_dragOffset + d.delta.dx).clamp(0.0, _threshold + 12);
    });
    if (!_triggered && _dragOffset >= _threshold) {
      _triggered = true;
      widget.onReply();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    setState(() {
      _dragOffset = 0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Reply icon that appears as you drag
          if (_dragOffset > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Opacity(
                    opacity: (_dragOffset / _threshold).clamp(0.0, 1.0),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.reply, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ),
          // Slide the bubble to the right
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
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

// ── Reply quote widget (shown inside a bubble) ───────────────────────────
class _ReplyQuote extends StatelessWidget {
  final String senderName;
  final String text;
  final bool isMe;
  final VoidCallback? onTap;

  const _ReplyQuote({
    required this.senderName,
    required this.text,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isMe
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.08);
    final barColor = isMe ? Colors.white70 : AppColors.primary;
    final nameColor = isMe ? Colors.white : AppColors.primary;
    final textColor =
        isMe ? Colors.white.withValues(alpha: 0.8) : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              Flexible(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          color: nameColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final String myUid;
  final String otherUserId;
  final String convId;
  final bool highlighted;
  final VoidCallback? onTapReplyQuote;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.myUid,
    required this.otherUserId,
    required this.convId,
    this.highlighted = false,
    this.onTapReplyQuote,
  });

  void _onLongPress(BuildContext context) {
    // Already deleted for this user — nothing to show
    final hiddenForMe = msg.deleted || msg.deletedFor.contains(myUid);
    if (hiddenForMe) return;

    showModalBottomSheet(
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
            const SizedBox(height: 4),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete for everyone',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('Removed for all participants'),
                onTap: () async {
                  Navigator.pop(context);
                  await ChatService.instance.deleteMessage(convId, msg.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.orange),
              title: const Text('Delete for me',
                  style: TextStyle(color: Colors.orange)),
              subtitle: const Text('Hidden only on your device'),
              onTap: () async {
                Navigator.pop(context);
                await ChatService.instance.deleteForMe(convId, msg.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hiddenForMe = msg.deleted || msg.deletedFor.contains(myUid);
    final isImage = msg.type == 'image' && !hiddenForMe;
    final isFile = msg.type == 'file' && !hiddenForMe;

    return GestureDetector(
      onLongPress: () => _onLongPress(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: highlighted
              ? Colors.amber.shade200
              : hiddenForMe
                  ? (isMe
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.grey[200])
                  : (isMe ? AppColors.primary : Colors.white),
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
              // ── Quoted message ──────────────────────────────────────
              if (!hiddenForMe && msg.replyToId != null)
                _ReplyQuote(
                  senderName: msg.replyToSenderName ?? '',
                  text: msg.replyToText ?? '',
                  isMe: isMe,
                  onTap: onTapReplyQuote,
                ),
              if (hiddenForMe)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block,
                        size: 13,
                        color: isMe
                            ? Colors.white60
                            : AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      msg.deleted ? 'Message deleted' : 'You deleted this message',
                      style: TextStyle(
                        color: isMe
                            ? Colors.white60
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else if (isImage && msg.mediaUrl != null)
                _ImageContent(url: msg.mediaUrl!, isMe: isMe)
              else if (isFile && msg.mediaUrl != null)
                _FileContent(
                  url: msg.mediaUrl!,
                  fileName: msg.fileName ?? 'File',
                  isMe: isMe,
                )
              else
                _LinkText(text: msg.text, isMe: isMe),
              if (!hiddenForMe) ...[
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
            ],
          ),
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => _ImageViewerScreen(url: url)),
      ),
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

// ── Linkify text (makes URLs tappable) ────────────────────────────────────
class _LinkText extends StatefulWidget {
  final String text;
  final bool isMe;
  const _LinkText({required this.text, required this.isMe});

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  static final _urlRegex = RegExp(r'https?://\S+', caseSensitive: false);
  final _recognizers = <TapGestureRecognizer>[];
  late TextSpan _span;

  @override
  void initState() {
    super.initState();
    _buildSpan();
  }

  @override
  void didUpdateWidget(_LinkText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.isMe != widget.isMe) {
      for (final r in _recognizers) r.dispose();
      _recognizers.clear();
      _buildSpan();
    }
  }

  void _buildSpan() {
    final matches = _urlRegex.allMatches(widget.text).toList();
    final baseColor = widget.isMe ? Colors.white : AppColors.textPrimary;
    final linkColor =
        widget.isMe ? Colors.lightBlueAccent : AppColors.primary;
    const sz = 14.5;

    if (matches.isEmpty) {
      _span = TextSpan(
        text: widget.text,
        style: TextStyle(color: baseColor, fontSize: sz),
      );
      return;
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: widget.text.substring(cursor, m.start),
          style: TextStyle(color: baseColor, fontSize: sz),
        ));
      }
      final url = m.group(0)!;
      final r = TapGestureRecognizer()..onTap = () => _openUrl(url);
      _recognizers.add(r);
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: linkColor,
          fontSize: sz,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: r,
      ));
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(cursor),
        style: TextStyle(color: baseColor, fontSize: sz),
      ));
    }
    _span = TextSpan(children: spans);
  }

  @override
  void dispose() {
    for (final r in _recognizers) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RichText(text: _span);
}

// ── Scroll-to-bottom FAB ────────────────────────────────────────────────────
class _ScrollFab extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _ScrollFab({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.keyboard_arrow_down,
                color: AppColors.primary, size: 26),
          ),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
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

// ── Full-screen image viewer ─────────────────────────────────────────────
class _ImageViewerScreen extends StatelessWidget {
  final String url;
  const _ImageViewerScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
            onPressed: () => _openUrl(url),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, prog) {
              if (prog == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: prog.expectedTotalBytes != null
                      ? prog.cumulativeBytesLoaded /
                          prog.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
