import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';

import '../bloc/language_cubit.dart';
import 'chat_screen.dart';

/// ============================================================================
/// CHATS SCREEN (Modernized & Laptop-Responsive)
/// ============================================================================

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final firestoreService = FirestoreService();
    final t = context.watch<LanguageCubit>().state.t;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------------------------
                // ELEVATED APP BAR / HEADER
                // ------------------------------------------------------------------
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 20,
                    16,
                    isDesktop ? 28 : 20,
                    12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('chats_title'),
                            style: TextStyle(
                              fontSize: isDesktop ? 26 : 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF14241F),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t('greeting_sub'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F5A47).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 15,
                              color: Color(0xFF0F5A47),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'PRO 24/7',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F5A47),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // ------------------------------------------------------------------
                // CHAT STREAM BUILDER
                // ------------------------------------------------------------------
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: firestoreService.streamChatsForClient(user.uid),
                    builder: (context, snapshot) {
                      // Error State
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 44,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${t('error')}: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Loading State with Smooth Shimmer-style Card
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF0F5A47),
                          ),
                        );
                      }

                      final chats = snapshot.data!;

                      // Modern Empty State
                      if (chats.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F5A47).withOpacity(0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 38,
                                    color: Color(0xFF0F5A47),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  t('chats_empty_title'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E2D27),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 320),
                                  child: Text(
                                    t('chats_empty_sub'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Dynamic List Layout
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 28 : 16,
                          6,
                          isDesktop ? 28 : 16,
                          30,
                        ),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _ChatTile(
                            chat: chats[index],
                            uid: user.uid,
                            firestoreService: firestoreService,
                            t: t,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ELEVATED CHAT CARD
// ============================================================================

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.uid,
    required this.firestoreService,
    required this.t,
  });

  final Map<String, dynamic> chat;
  final String uid;
  final FirestoreService firestoreService;
  final String Function(String) t;

  String _formatTime(dynamic value) {
    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate();
    final now = DateTime.now();

    final sameDay =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (sameDay) {
      return DateFormat('HH:mm').format(date);
    }

    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final techId = chat['techId'] as String?;
    final requestId = chat['requestId'] as String?;

    if (techId == null || techId.isEmpty || requestId == null) {
      return const SizedBox.shrink();
    }

    final serviceLabel =
        chat['serviceLabel'] as String? ?? t('chat_default_service');

    final lastText =
        chat['lastMessageText'] as String? ?? t('chat_start_conversation');

    final time = _formatTime(chat['lastMessageAt'] ?? chat['createdAt']);
    final unread = FirestoreService.hasUnread(chat, uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestoreService.streamTechnician(techId),
      builder: (context, snapshot) {
        final tech = snapshot.data?.data();

        final name =
            tech?['fullName'] as String? ?? t('chat_default_technician');

        final photoUrl = tech?['profilePhotoUrl'] as String?;

        return Material(
          color: unread ? const Color(0xFFF1F8F5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: unread ? 2 : 0,
          shadowColor: const Color(0xFF0F5A47).withOpacity(0.08),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    requestId: requestId,
                    title: name,
                    techId: techId,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: unread
                      ? const Color(0xFF0F5A47).withOpacity(0.35)
                      : Colors.grey.withOpacity(0.12),
                  width: unread ? 1.4 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Technician Avatar with Online / Active Glow
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: unread
                                ? const Color(0xFF0F5A47)
                                : Colors.transparent,
                            width: 1.8,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFF0F5A47).withOpacity(0.08),
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF0F5A47),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (unread)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Message Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row (Name + Time)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: unread
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: const Color(0xFF1E2D27),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: unread
                                    ? const Color(0xFF0F5A47)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Service Pill Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F5A47).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            serviceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F5A47),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Last Message Snippet
                        Text(
                          lastText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: unread
                                ? const Color(0xFF13231D)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Trailing Chevron indicator
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: unread
                        ? const Color(0xFF0F5A47)
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}