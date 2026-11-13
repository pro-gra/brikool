import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';

/// Chat between a client and a company on one big-project request —
/// keeps the whole negotiation and follow-up inside the app instead
/// of contacts being exchanged and the platform cut out entirely.
class CompanyChatScreen extends StatefulWidget {
  const CompanyChatScreen({super.key, required this.requestId, required this.title});
  final String requestId;
  final String title;

  @override
  State<CompanyChatScreen> createState() => _CompanyChatScreenState();
}

class _CompanyChatScreenState extends State<CompanyChatScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sendingMedia = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) _firestoreService.markCompanyChatRead(widget.requestId, uid);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _textController.clear();
    try {
      await _firestoreService.sendCompanyMessage(
          requestId: widget.requestId, senderId: uid, type: 'text', text: text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Échec de l\'envoi')));
      }
    }
  }

  Future<void> _sendPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;
    setState(() => _sendingMedia = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await _storageService.upload(
        path: 'company_chats/${widget.requestId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
        localPathOrIgnoredOnWeb: file.path,
        bytes: bytes,
        contentType: 'image/jpeg',
      );
      await _firestoreService.sendCompanyMessage(
          requestId: widget.requestId, senderId: uid, type: 'image', mediaUrl: url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Échec de l\'envoi de la photo')));
      }
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreService.streamCompanyMessages(widget.requestId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Dites bonjour 👋',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: messages[i], isMine: messages[i]['senderId'] == uid),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    _sendingMedia
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            onPressed: _sendPhoto,
                            icon: const Icon(Icons.image_rounded, color: AppColors.primary),
                            tooltip: 'Photo',
                          ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Écrivez un message…',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});
  final Map<String, dynamic> message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final type = message['type'] as String? ?? 'text';
    final createdAt = message['createdAt'];
    final time = createdAt is Timestamp ? DateFormat('HH:mm').format(createdAt.toDate()) : '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 10),
        padding: type == 'image'
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'image')
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                        child: InteractiveViewer(
                            child: Image.network(message['mediaUrl'] as String))),
                  ),
                  child: Image.network(message['mediaUrl'] as String,
                      width: 180, height: 180, fit: BoxFit.cover),
                ),
              )
            else
              Text(message['text'] as String? ?? '',
                  style: TextStyle(
                      fontSize: 14, color: isMine ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(
                    fontSize: 9.5,
                    color: isMine ? Colors.white70 : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}