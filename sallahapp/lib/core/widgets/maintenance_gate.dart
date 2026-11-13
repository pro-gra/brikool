// lib/core/widgets/maintenance_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../splash_screen.dart';

/// Wraps the entire app. Streams live from Firestore so any change
/// (maintenance toggle OR ban) takes effect INSTANTLY on all open
/// sessions — no restart required.
class MaintenanceGate extends StatelessWidget {
  const MaintenanceGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Layer 1: maintenance mode — public read, instant
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('maintenance')
          .snapshots(),
      builder: (context, maintenanceSnap) {
        final data = maintenanceSnap.data?.data();
        final isMaintenanceActive = data?['active'] as bool? ?? false;
        final message = data?['message'] as String? ??
            'Application temporairement indisponible.\nRevenez bientôt.';

        // Layer 2: auth state
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            final user = authSnap.data;

            // Not logged in
            if (user == null) {
              if (isMaintenanceActive) {
                return _MaintenanceScreen(message: message);
              }
              return const SplashScreen();
            }

            // Logged in — check if admin (admins bypass maintenance)
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admins')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, adminSnap) {
                final isAdmin = adminSnap.data?.exists ?? false;

                // Maintenance screen (non-admins only)
                if (isMaintenanceActive && !isAdmin) {
                  return _MaintenanceScreen(message: message);
                }

                // Layer 3: ban check — users collection
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data();
                    final isBannedUser = userData?['isBanned'] as bool? ?? false;

                    if (isBannedUser) {
                      // Sign out silently so next open shows login screen
                      FirebaseAuth.instance.signOut();
                      return _BannedScreen(
                        reason: userData?['banReason'] as String? ?? '',
                        bannedUntil: userData?['bannedUntil'],
                      );
                    }

                    // Layer 4: ban check — technicians collection
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('technicians')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, techSnap) {
                        final techData = techSnap.data?.data();
                        final isBannedTech = techData?['isBanned'] as bool? ?? false;

                        if (isBannedTech) {
                          FirebaseAuth.instance.signOut();
                          return _BannedScreen(
                            reason: techData?['banReason'] as String? ?? '',
                            bannedUntil: techData?['bannedUntil'],
                          );
                        }

                        // All checks passed — show the app
                        return const SplashScreen();
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BannedScreen extends StatelessWidget {
  const _BannedScreen({required this.reason, this.bannedUntil});
  final String reason;
  final dynamic bannedUntil;

  String get _untilText {
    if (bannedUntil == null) return 'Bannissement permanent';
    try {
      final date = (bannedUntil as dynamic).toDate() as DateTime;
      return 'Jusqu\'au ${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrikolIcon(size: 80),
              const SizedBox(height: 28),
              const Text('brikol.ma',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Column(children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 36),
                  const SizedBox(height: 12),
                  const Text('Compte suspendu',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (reason.isNotEmpty)
                    Text('Raison: $reason',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.4)),
                  if (_untilText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_untilText,
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                      'Pour contester cette décision,\ncontactez le support Brikol.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white60, fontSize: 12, height: 1.5)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrikolIcon(size: 90),
              const SizedBox(height: 28),
              const Text('brikol.ma',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              const SizedBox(height: 10),
              Container(width: 40, height: 2, color: AppColors.gold),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(children: [
                  const Icon(Icons.build_rounded, color: AppColors.gold, size: 32),
                  const SizedBox(height: 12),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.5)),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('خدمة نقية... فبلاصتك',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}