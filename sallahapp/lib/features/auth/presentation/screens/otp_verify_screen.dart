import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.authService,
    required this.phoneNumber,
  });

  final AuthService authService;
  final String phoneNumber;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _firestoreService = FirestoreService();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = await widget.authService.verifyOtp(smsCode: code);
      final user = credential.user;

      if (user != null) {
        // انتظر حتى يكمل الكتابة فـ Firestore
        await _firestoreService.ensureUserProfile(user, preferredLang: 'fr');
      }

      if (!mounted) return;

      // delay صغير باش Firestore يتأكد من الكتابة قبل AuthGate يقرأ
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Code incorrect, veuillez réessayer';
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entrez le code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Code envoyé au ${widget.phoneNumber}',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(counterText: ''),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Vérifier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}