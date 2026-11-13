import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';

import '../bloc/language_cubit.dart';

import 'home_screen.dart';
import 'orders_screen.dart';
import 'chats_screen.dart';
import 'profile_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    NotificationService().registerRoute(
      'new_offer',
      (requestId) => OrderDetailScreen(requestId: requestId),
    );

    NotificationService().registerRoute(
      'status_en_route',
      (requestId) => OrderDetailScreen(requestId: requestId),
    );

    NotificationService().registerRoute(
      'status_in_progress',
      (requestId) => OrderDetailScreen(requestId: requestId),
    );

    NotificationService().registerRoute(
      'status_completed',
      (requestId) => OrderDetailScreen(requestId: requestId),
    );

    await NotificationService().init(
      uid: uid,
      collection: 'users',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, langState) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7FAFA),
          body: IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              OrdersScreen(),
              ChatsScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.streamChatsForClient(user.uid),
            builder: (context, chatSnap) {
              final chats = chatSnap.data ?? [];
              final unread = chats
                  .where(
                    (c) => FirestoreService.hasUnread(
                      c,
                      user.uid,
                    ),
                  )
                  .length;

              return Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavDestinationItem(
                        icon: Icons.home_rounded,
                        label: langState.t('nav_home'),
                        isSelected: _index == 0,
                        onTap: () => setState(() => _index = 0),
                      ),
                      _NavDestinationItem(
                        icon: Icons.receipt_long_rounded,
                        label: langState.t('nav_orders'),
                        isSelected: _index == 1,
                        onTap: () => setState(() => _index = 1),
                      ),
                      _NavDestinationItem(
                        icon: Icons.chat_bubble_rounded,
                        label: langState.t('chats_title'),
                        isSelected: _index == 2,
                        unreadCount: unread,
                        onTap: () => setState(() => _index = 2),
                      ),
                      _NavDestinationItem(
                        icon: Icons.person_rounded,
                        label: langState.t('nav_profile'),
                        isSelected: _index == 3,
                        onTap: () => setState(() => _index = 3),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NavDestinationItem extends StatelessWidget {
  const _NavDestinationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.unreadCount = 0,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF0F5A47);
    final inactiveColor = Colors.grey.shade400;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: activeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}