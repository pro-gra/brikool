import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_skill.dart';

import '../bloc/language_cubit.dart';
import 'technician_public_profile.dart';
import 'audio_helper.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.requestId,
    required this.title,
    this.techId,
  });

  final String requestId;
  final String title;
  final String? techId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sendingMedia = false;
  bool _recording = false;
  bool _sendingAudio = false;

  int _recordSecs = 0;
  Timer? _recordTimer;

  final _webRec = WebRecorderHelper();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fs.markChatRead(widget.requestId, _uid);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    _textCtrl.clear();

    try {
      await _fs.sendMessage(
        requestId: widget.requestId,
        senderId: _uid,
        type: 'text',
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _textCtrl.text = text;
        final t = context.read<LanguageCubit>().state.t;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('chat_error')}: $e')),
        );
      }
    }
  }

  Future<void> _sendMedia({required bool isVideo}) async {
    final file = isVideo
        ? await _picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(seconds: 30),
          )
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 70,
          );

    if (file == null) return;

    setState(() => _sendingMedia = true);

    try {
      final bytes = await file.readAsBytes();
      final ext = isVideo ? 'mp4' : 'jpg';

      final url = await _storage.upload(
        path: 'chats/${widget.requestId}/${DateTime.now().millisecondsSinceEpoch}.$ext',
        localPathOrIgnoredOnWeb: file.path,
        bytes: bytes,
        contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      );

      await _fs.sendMessage(
        requestId: widget.requestId,
        senderId: _uid,
        type: isVideo ? 'video' : 'image',
        mediaUrl: url,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        final t = context.read<LanguageCubit>().state.t;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('chat_error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  Future<void> _sendLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final pos = await Geolocator.getCurrentPosition();

      await _fs.sendMessage(
        requestId: widget.requestId,
        senderId: _uid,
        type: 'location',
        lat: pos.latitude,
        lng: pos.longitude,
      );

      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        final t = context.read<LanguageCubit>().state.t;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('chat_location_unavailable'))),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    final t = context.read<LanguageCubit>().state.t;

    if (!kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('chat_voice_web_only'))),
        );
      }
      return;
    }

    try {
      await _webRec.start();
      _startTimer();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('chat_microphone_unavailable'))),
        );
      }
    }
  }

  void _stopRecording() {
    if (kIsWeb) _stopWeb();
  }

  void _cancelRecording() {
    _recordTimer?.cancel();
    setState(() {
      _recording = false;
      _recordSecs = 0;
    });
    if (kIsWeb) _webRec.cancel();
  }

  Future<void> _stopWeb() async {
    _recordTimer?.cancel();
    final dur = _recordSecs;

    setState(() => _recording = false);
    if (mounted) setState(() => _sendingAudio = true);

    try {
      final bytes = await _webRec.stop();
      if (bytes == null || bytes.isEmpty) return;

      final path = 'chats/${widget.requestId}/${_uid}_${DateTime.now().millisecondsSinceEpoch}.webm';
      final ref = FirebaseStorage.instance.ref().child(path);

      await ref.putData(
        bytes as dynamic,
        SettableMetadata(contentType: 'audio/webm'),
      );

      final url = await ref.getDownloadURL();

      await _fs.sendMessage(
        requestId: widget.requestId,
        senderId: _uid,
        type: 'audio',
        mediaUrl: url,
        duration: dur,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        final t = context.read<LanguageCubit>().state.t;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('chat_audio_error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingAudio = false);
    }
  }

  void _startTimer() {
    setState(() {
      _recording = true;
      _recordSecs = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSecs++);
    });
  }

  String _fmt(int seconds) {
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final t = context.read<LanguageCubit>().state.t;

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(t('chat_delete_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(
          t('chat_delete_message'),
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t('cancel'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('delete'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _fs.hideChatForClient(widget.requestId);
      if (ctx.mounted) Navigator.pop(ctx);
    }
  }

  String? _specialtyLabel(List<String>? ids) {
    if (ids == null || ids.isEmpty) return null;

    final labels = ids
        .map((id) {
          for (final skill in TechnicianSkill.all) {
            if (skill.id == id) return skill.label;
          }
          return null;
        })
        .whereType<String>()
        .toList();

    return labels.isEmpty ? null : labels.take(2).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF192A24)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.techId != null
              ? () => showTechnicianPublicProfile(context, widget.techId!)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: StreamBuilder<TechnicianProfile?>(
              stream: widget.techId != null ? _fs.streamTechnicianProfile(widget.techId!) : null,
              builder: (ctx, snap) {
                final tech = snap.data;
                final label = _specialtyLabel(tech?.skills);

                return Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFF0F5A47).withOpacity(0.1),
                          backgroundImage: tech?.profilePhotoUrl != null
                              ? NetworkImage(tech!.profilePhotoUrl!)
                              : null,
                          child: tech?.profilePhotoUrl == null
                              ? Text(
                                  widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF0F5A47),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF192A24),
                            ),
                          ),
                          Text(
                            label ?? t('chat_default_technician'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF192A24)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'profile' && widget.techId != null) {
                showTechnicianPublicProfile(context, widget.techId!);
              } else if (value == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (_) => [
              if (widget.techId != null)
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, size: 18, color: Color(0xFF0F5A47)),
                      const SizedBox(width: 10),
                      Text(t('chat_view_profile'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Text(t('delete'), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
            child: Container(
              decoration: isDesktop
                  ? BoxDecoration(
                      color: const Color(0xFFF9FBFB),
                      border: Border.symmetric(vertical: BorderSide(color: Colors.grey.withOpacity(0.18))),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : null,
              child: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _fs.streamMessages(widget.requestId),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFF0F5A47)),
                          );
                        }

                        final msgs = snap.data!;

                        if (msgs.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.withOpacity(0.14)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.waving_hand_rounded, color: Color(0xFFF59E0B), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    t('chat_say_hello'),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) {
                            return _MessageBubble(
                              message: msgs[i],
                              isMine: msgs[i]['senderId'] == _uid,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (_sendingMedia || _sendingAudio)
                    const LinearProgressIndicator(
                      minHeight: 2.5,
                      color: Color(0xFF0F5A47),
                      backgroundColor: Color(0xFFD4EDE5),
                    ),

                  // Bottom Message Composer
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.withOpacity(0.12)),
                      ),
                    ),
                    child: _recording
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _cancelRecording,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.danger,
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: const BoxDecoration(
                                          color: AppColors.danger,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _fmt(_recordSecs),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        t('chat_recording'),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _stopRecording,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0F5A47),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              _ActionIconButton(
                                icon: Icons.image_rounded,
                                onPressed: _sendingMedia ? null : () => _sendMedia(isVideo: false),
                              ),
                              _ActionIconButton(
                                icon: Icons.videocam_rounded,
                                onPressed: _sendingMedia ? null : () => _sendMedia(isVideo: true),
                              ),
                              _ActionIconButton(
                                icon: Icons.location_on_rounded,
                                onPressed: _sendLocation,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F7F5),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                  ),
                                  child: TextField(
                                    controller: _textCtrl,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendText(),
                                    decoration: InputDecoration(
                                      hintText: t('chat_hint_message'),
                                      hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (kIsWeb)
                                GestureDetector(
                                  onTap: _recording ? _stopRecording : _startRecording,
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: _recording ? AppColors.danger : const Color(0xFF0F5A47).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _recording ? Icons.stop_rounded : Icons.mic_rounded,
                                      color: _recording ? Colors.white : const Color(0xFF0F5A47),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 4),
                              Material(
                                color: const Color(0xFF0F5A47),
                                borderRadius: BorderRadius.circular(22),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: _sendingAudio ? null : _sendText,
                                  child: const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: Icon(
                                      Icons.send_rounded,
                                      size: 19,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF0F5A47), size: 21),
        splashRadius: 20,
        onPressed: onPressed,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
  });

  final Map<String, dynamic> message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageCubit>().state.t;
    final type = message['type'] as String? ?? 'text';

    Widget content;

    switch (type) {
      case 'image':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            message['mediaUrl'] as String? ?? '',
            width: 230,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        );

      case 'video':
        content = InkWell(
          onTap: () {
            final url = message['mediaUrl'] as String?;
            if (url != null) launchUrl(Uri.parse(url));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  size: 26,
                  color: isMine ? Colors.white : const Color(0xFF0F5A47),
                ),
                const SizedBox(width: 8),
                Text(
                  t('chat_video_tap_to_play'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'location':
        final lat = message['lat'];
        final lng = message['lng'];

        content = InkWell(
          onTap: () {
            launchUrl(Uri.parse('https://www.google.com/maps?q=$lat,$lng'));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 24,
                  color: isMine ? Colors.white : AppColors.danger,
                ),
                const SizedBox(width: 8),
                Text(
                  t('chat_location_shared'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );

      case 'audio':
        content = _AudioBubble(
          url: message['mediaUrl'] as String? ?? '',
          duration: (message['audioDuration'] as num?)?.toInt() ?? 0,
          isMine: isMine,
        );

      default:
        content = Text(
          message['text'] as String? ?? '',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: isMine ? Colors.white : const Color(0xFF192A24),
          ),
        );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: type == 'audio'
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          gradient: isMine
              ? const LinearGradient(
                  colors: [Color(0xFF0F5A47), Color(0xFF07382B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: isMine ? null : Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: isMine ? const Color(0xFF0F5A47).withOpacity(0.2) : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  const _AudioBubble({
    required this.url,
    required this.duration,
    required this.isMine,
  });

  final String url;
  final int duration;
  final bool isMine;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _webPlayer = WebPlayerHelper();
  AudioPlayer? _nativePlayer;

  bool _playing = false;
  int _position = 0;
  Timer? _progressTimer;

  static const List<double> _bars = [
    0.3, 0.5, 0.2, 0.8, 0.4, 0.9, 0.6, 1.0, 0.7, 0.3,
    0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 0.5, 0.2, 0.6,
  ];

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _webPlayer.init(
        widget.url,
        onEnded: () {
          if (mounted) {
            setState(() {
              _playing = false;
              _position = 0;
            });
          }
          _progressTimer?.cancel();
        },
      );
    } else {
      _nativePlayer = AudioPlayer();

      _nativePlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = 0;
          });
        }
        _progressTimer?.cancel();
      });

      _nativePlayer!.onPositionChanged.listen((duration) {
        if (mounted) {
          setState(() => _position = duration.inSeconds);
        }
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _webPlayer.dispose();
    _nativePlayer?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (kIsWeb) {
      if (_playing) {
        _webPlayer.pause();
        _progressTimer?.cancel();
        if (mounted) setState(() => _playing = false);
      } else {
        _webPlayer.play();
        if (mounted) setState(() => _playing = true);

        _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _position = _webPlayer.currentSeconds);
          }
        });
      }
    } else {
      if (_playing) {
        await _nativePlayer!.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _nativePlayer!.play(UrlSource(widget.url));
        if (mounted) setState(() => _playing = true);
      }
    }
  }

  void _seek(double factor) {
    if (widget.duration == 0) return;
    final seconds = (factor * widget.duration).round();

    if (kIsWeb) {
      _webPlayer.seek(seconds);
    } else {
      _nativePlayer?.seek(Duration(seconds: seconds));
    }

    if (mounted) setState(() => _position = seconds);
  }

  String _fmt(int seconds) {
    return '${(seconds ~/ 60).toString().padLeft(1, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (widget.duration == 0) return 0.0;
    return (_position / widget.duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? Colors.white : const Color(0xFF0F5A47);
    final fgOff = widget.isMine ? Colors.white38 : Colors.grey.shade300;
    final bg = widget.isMine ? Colors.white24 : const Color(0xFF0F5A47).withOpacity(0.1);
    final muted = widget.isMine ? Colors.white70 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(
              Icons.mic_rounded,
              color: widget.isMine ? Colors.white : const Color(0xFF0F5A47),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMine ? Colors.white : const Color(0xFF0F5A47),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTapDown: (details) {
                  _seek((details.localPosition.dx / 120).clamp(0.0, 1.0));
                },
                child: Container(
                  height: 24,
                  width: 120,
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_bars.length, (i) {
                      final played = (i + 1) / _bars.length <= _progress;
                      return Container(
                        width: 2.5,
                        height: 20 * _bars[i],
                        decoration: BoxDecoration(
                          color: played ? fg : fgOff,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _playing ? _fmt(_position) : _fmt(widget.duration),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}