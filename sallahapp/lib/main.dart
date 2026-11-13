import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/services/firestore_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'models/technician_profile.dart';
import 'features/client/presentation/bloc/language_cubit.dart';
import 'features/client/presentation/screens/client_shell.dart';
import 'features/auth/presentation/screens/phone_login_screen.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/auth/presentation/screens/role_selection_screen.dart';
import 'features/auth/presentation/screens/client_onboarding_screen.dart';
import 'features/technician/presentation/screens/technician_onboarding_screen.dart';
import 'features/technician/presentation/screens/wallet_deposit_screen.dart';
import 'features/technician/presentation/screens/technician_shell.dart';
import 'features/admin/presentation/screens/admin_shell.dart';
import 'models/company_profile.dart';
import 'features/company/presentation/screens/company_registration_screen.dart';
import 'features/company/presentation/screens/company_shell.dart';
import 'package:audioplayers/audioplayers.dart';
import 'splash_screen.dart';
import 'core/localization/app_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    try { await AudioPlayer.global.setAudioContext(AudioContext()); } catch (_) {}
  }
  if (!kIsWeb) {
    try { FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler); } catch (_) {}
  }
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // ── Stripe — mobile only (Web not supported) ──────────────────
  if (!kIsWeb) {
    Stripe.publishableKey =
        'pk_test_51U9fC73VTFFs2Qu4Y7NbbgN15y3D6y2NyVOruR9OTxGcUwApUehI4k1us2CD43QQ0S8nD5gQmBdpVxo6hbrK0pXM00ZnjR3FrL';
    await Stripe.instance.applySettings();
  }

  runApp(const BrikolApp());
}

class BrikolApp extends StatelessWidget {
  const BrikolApp({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LanguageCubit(initialLanguage: AppLanguage.ar),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc('maintenance')
            .snapshots(),
        builder: (context, maintenanceSnap) {
          final mData = maintenanceSnap.data?.data();
          final isMaintenance = mData?['active'] as bool? ?? false;
          final maintenanceMsg = mData?['message'] as String? ??
              'Application temporairement indisponible.\nRevenez bientôt.';
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnap) {
              final user = authSnap.data;
              return MaterialApp(
                navigatorKey: rootNavigatorKey,
                title: 'brikool',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                home: const AuthGate(),
                builder: (context, child) {
                  return _AppOverlay(
                    isMaintenance: isMaintenance,
                    maintenanceMsg: maintenanceMsg,
                    user: user,
                    child: child!,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AppOverlay extends StatelessWidget {
  const _AppOverlay({
    required this.isMaintenance,
    required this.maintenanceMsg,
    required this.user,
    required this.child,
  });
  final bool isMaintenance;
  final String maintenanceMsg;
  final User? user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      if (isMaintenance) return _MaintenanceScreen(message: maintenanceMsg);
      return child;
    }
    if (isMaintenance) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('admins').doc(user!.uid).get(),
        builder: (context, snap) {
          final isAdmin = snap.data?.exists ?? false;
          if (isMaintenance && !isAdmin) return _MaintenanceScreen(message: maintenanceMsg);
          return child;
        },
      );
    }
    return _BanCheckWrapper(user: user!, child: child);
  }
}

class _BanCheckWrapper extends StatefulWidget {
  const _BanCheckWrapper({required this.user, required this.child});
  final User user;
  final Widget child;
  @override
  State<_BanCheckWrapper> createState() => _BanCheckWrapperState();
}

class _BanCheckWrapperState extends State<_BanCheckWrapper> {
  bool _isBanned = false;
  String _banReason = '';
  dynamic _bannedUntil;

  @override
  void initState() {
    super.initState();
    _checkBan();
  }

  Future<void> _checkBan() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(widget.user.uid).get();
      final userData = userDoc.data();
      if (userData?['isBanned'] == true) {
        if (mounted) {
          setState(() {
            _isBanned = true;
            _banReason = userData?['banReason'] as String? ?? '';
            _bannedUntil = userData?['bannedUntil'];
          });
          FirebaseAuth.instance.signOut();
        }
        return;
      }
      final techDoc = await FirebaseFirestore.instance
          .collection('technicians').doc(widget.user.uid).get();
      final techData = techDoc.data();
      if (techData?['isBanned'] == true) {
        if (mounted) {
          setState(() {
            _isBanned = true;
            _banReason = techData?['banReason'] as String? ?? '';
            _bannedUntil = techData?['bannedUntil'];
          });
          FirebaseAuth.instance.signOut();
        }
      }
    } catch (e) {
      debugPrint('BAN CHECK ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBanned) return _BannedScreen(reason: _banReason, bannedUntil: _bannedUntil);
    return widget.child;
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
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const BrikolIcon(size: 80), const SizedBox(height: 28),
        const Text('brikool', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.withOpacity(0.4))),
          child: Column(children: [
            const Icon(Icons.block_rounded, color: Colors.redAccent, size: 36), const SizedBox(height: 12),
            const Text('Compte suspendu', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (reason.isNotEmpty) Text('Raison: $reason', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4)),
            if (_untilText.isNotEmpty) ...[const SizedBox(height: 6),
              Text(_untilText, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600))],
            const SizedBox(height: 16),
            const Text('Pour contester,\ncontactez le support Brikol.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
          ])),
      ]))),
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
      body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const BrikolIcon(size: 90), const SizedBox(height: 28),
        const Text('brikool', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Container(width: 40, height: 2, color: AppColors.gold),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
          child: Column(children: [
            const Icon(Icons.build_rounded, color: AppColors.gold, size: 32), const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
          ])),
        const SizedBox(height: 24),
        const Text('خدمة نقية... فبلاصتك', textDirection: TextDirection.rtl,
            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w500)),
      ]))),
    );
  }
}

// ================================================================
// AUTH GATE
// ================================================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastEnsuredUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final user = authSnapshot.data;
        if (user == null) return const WelcomeScreen();
        if (_lastEnsuredUid != user.uid) {
          _lastEnsuredUid = user.uid;
          FirestoreService().ensureUserProfile(user, preferredLang: 'ar');
        }
        return _AdminGate(uid: user.uid);
      },
    );
  }
}

// ================================================================
// ADMIN GATE
// ================================================================
class _AdminGate extends StatelessWidget {
  const _AdminGate({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('admins').doc(uid).get()
          .timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('timeout')),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingScaffold();
        if (snap.hasError) return _CompanyGate(uid: uid);
        if (snap.data?.exists == true) return const AdminShell();
        return _CompanyGate(uid: uid);
      },
    );
  }
}

class _CompanyGate extends StatelessWidget {
  const _CompanyGate({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('companies').doc(uid).get()
          .timeout(const Duration(seconds: 10), onTimeout: () => throw Exception('timeout')),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingScaffold();
        if (snap.hasError || snap.data?.exists != true) return _RoleGate(uid: uid);
        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return _RoleGate(uid: uid);
        try {
          final company = CompanyProfile.fromMap(uid, data);
          if (!company.onboardingComplete) return const CompanyRegistrationScreen();
          return CompanyShell(profile: company);
        } catch (_) {
          return _RoleGate(uid: uid);
        }
      },
    );
  }
}

// ================================================================
// ROLE GATE
// ================================================================
class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    return StreamBuilder<String?>(
      stream: fs.streamUserRole(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingScaffold();
        if (snap.connectionState == ConnectionState.active && !snap.hasData) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) FirestoreService().ensureUserProfile(user, preferredLang: 'ar');
          return const RoleSelectionScreen();
        }
        final role = snap.data;
        if (role == null || role.isEmpty) return const RoleSelectionScreen();
        if (role == 'client') return _ClientGate(uid: uid, fs: fs);
        if (role == 'technician') return _TechnicianGate(uid: uid, fs: fs);
        return const RoleSelectionScreen();
      },
    );
  }
}

// ================================================================
// CLIENT GATE
// ================================================================
class _ClientGate extends StatelessWidget {
  const _ClientGate({required this.uid, required this.fs});
  final String uid;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fs.getUserProfile(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingScaffold();
        if (snap.hasError) return const ClientShell();
        final data = snap.data;
        if (data == null) return const ClientShell();
        final complete = data['clientOnboardingComplete'] as bool? ?? false;
        if (!complete) return const ClientOnboardingScreen();
        return const ClientShell();
      },
    );
  }
}

// ================================================================
// TECHNICIAN GATE
// ================================================================
class _TechnicianGate extends StatelessWidget {
  const _TechnicianGate({required this.uid, required this.fs});
  final String uid;
  final FirestoreService fs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TechnicianProfile?>(
      stream: fs.streamTechnicianProfile(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _LoadingScaffold();
        if (snap.hasError) return const TechnicianOnboardingScreen();
        final profile = snap.data;
        if (profile == null) return const TechnicianOnboardingScreen();
        if (!profile.onboardingComplete) return const TechnicianOnboardingScreen();
        if (!profile.isVerified) return _PendingVerificationScreen(profile: profile);
        return TechnicianShell(profile: profile);
      },
    );
  }
}

// ================================================================
// PENDING VERIFICATION
// ================================================================
class _PendingVerificationScreen extends StatelessWidget {
  const _PendingVerificationScreen({required this.profile});
  final TechnicianProfile profile;

  @override
  Widget build(BuildContext context) {
    final firstName = profile.fullName.split(' ').first;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const BrikolIcon(size: 90),
            const SizedBox(height: 28),
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('Compte en cours de vérification',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              '${firstName.isEmpty ? 'Bonjour 👋' : 'Bonjour $firstName 👋'}\n\n'
              'Notre équipe examine votre profil (CIN, spécialités) avant de l\'activer. '
              'Délai habituel: moins de 24h.\n\n'
              'Dès que votre compte sera approuvé vous serez redirigé automatiquement.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Se déconnecter'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================================================================
// LOADING SCAFFOLD
// ================================================================
class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050f0a),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF0e8050), strokeWidth: 2.5)),
    );
  }
}