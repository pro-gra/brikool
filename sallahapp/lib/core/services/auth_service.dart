import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  ConfirmationResult? _webConfirmationResult;
  String? _mobileVerificationId;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Phone OTP ─────────────────────────────────────────────────────────────

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String message) onError,
  }) async {
    try {
      if (kIsWeb) {
        _webConfirmationResult =
            await _auth.signInWithPhoneNumber(phoneNumber);
        onCodeSent();
      } else {
        await _auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            await _auth.signInWithCredential(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            onError(e.message ?? 'Phone verification failed');
          },
          codeSent: (String verificationId, int? resendToken) {
            _mobileVerificationId = verificationId;
            onCodeSent();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _mobileVerificationId = verificationId;
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? 'Could not send SMS');
    } catch (e) {
      onError('Could not send SMS. Please try again.');
    }
  }

  Future<UserCredential> verifyOtp({required String smsCode}) async {
    if (kIsWeb) {
      final confirmation = _webConfirmationResult;
      if (confirmation == null) {
        throw StateError('No confirmation in progress — call sendOtp first.');
      }
      return confirmation.confirm(smsCode);
    }
    final verificationId = _mobileVerificationId;
    if (verificationId == null) {
      throw StateError('No verification in progress — call sendOtp first.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  // ── Google ────────────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        return await _auth.signInWithPopup(provider);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // user cancelled
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Google sign-in failed');
    }
  }

  // ── Email / Password ──────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _friendlyEmailError(e);
    }
  }

  Future<UserCredential> createAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw _friendlyEmailError(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _friendlyEmailError(e);
    }
  }

  Exception _friendlyEmailError(FirebaseAuthException e) {
    final messages = {
      'user-not-found': 'Aucun compte trouvé pour cet e-mail.',
      'wrong-password': 'Mot de passe incorrect.',
      'email-already-in-use': 'Cet e-mail est déjà utilisé.',
      'invalid-email': 'Adresse e-mail invalide.',
      'weak-password': 'Le mot de passe doit contenir au moins 6 caractères.',
      'too-many-requests': 'Trop de tentatives. Réessayez plus tard.',
      'network-request-failed': 'Erreur réseau. Vérifiez votre connexion.',
    };
    return Exception(messages[e.code] ?? e.message ?? 'Erreur d\'authentification.');
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      if (!kIsWeb) _googleSignIn.signOut(),
    ]);
  }
}