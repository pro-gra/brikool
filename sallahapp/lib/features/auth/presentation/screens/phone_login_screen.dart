import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import 'otp_verify_screen.dart';
import 'email_auth_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  bool _googleLoading = false;
  bool _focused = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawNumber = _phoneController.text.trim();

    if (rawNumber.isEmpty) {
      setState(() => _error = 'Veuillez saisir votre numéro de téléphone.');
      return;
    }
    if (rawNumber.length != 9) {
      setState(() => _error = 'Veuillez saisir un numéro marocain valide.');
      return;
    }

    final phoneNumber = '+212$rawNumber';
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    await _authService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              authService: _authService,
              phoneNumber: phoneNumber,
            ),
          ),
        );
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = message;
        });
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result == null && mounted) {
        setState(() => _googleLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _googleLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openEmail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailAuthScreen(authService: _authService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                22,
                24,
                keyboardInset > 0 ? keyboardInset + 20 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 50,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 64),
                        const Text(
                          'Bienvenue chez brikool.',
                          style: TextStyle(
                            color: Color(0xFF17231B),
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Connectez-vous pour trouver un professionnel de confiance, près de chez vous.',
                          style: TextStyle(
                            color: Color(0xFF758078),
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Text(
                          'NUMÉRO DE TÉLÉPHONE',
                          style: TextStyle(
                            color: Color(0xFF526057),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPhoneField(),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFB42318),
                                size: 17,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(.65),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Continuer',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0xFFE1E7E2)),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'OU',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade400,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0xFFE1E7E2)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _SocialButton(
                          label: 'Continuer avec Google',
                          icon: const _GoogleIcon(),
                          loading: _googleLoading,
                          onTap: _googleLoading ? null : _signInWithGoogle,
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          label: 'Continuer avec e-mail',
                          icon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 19,
                            color: Color(0xFF344139),
                          ),
                          loading: false,
                          onTap: _openEmail,
                        ),
                        const SizedBox(height: 28),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Color(0xFF7A887F),
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Connexion sécurisée. Vos données restent protégées.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF89948D),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 42),
                        const Center(
                          child: Text(
                            'LES SERVICES À DOMICILE, SIMPLEMENT.',
                            style: TextStyle(
                              color: Color(0xFFA0AAA3),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.home_repair_service_outlined,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'brikool',
          style: TextStyle(
            color: Color(0xFF17231B),
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE4EAE5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'MAROC',
            style: TextStyle(
              color: Color(0xFF526057),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _error != null
              ? const Color(0xFFB42318)
              : _focused
                  ? AppColors.primary
                  : const Color(0xFFDDE5DF),
          width: _focused || _error != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🇲🇦', style: TextStyle(fontSize: 18)),
                SizedBox(width: 7),
                Text(
                  '+212',
                  style: TextStyle(
                    color: Color(0xFF344139),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 25, color: const Color(0xFFE1E7E2)),
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _focusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: Color(0xFF17231B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
              decoration: const InputDecoration(
                hintText: '6XX XXX XXX',
                hintStyle: TextStyle(
                  color: Color(0xFFADB7B0),
                  fontSize: 14,
                  letterSpacing: .5,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF26332B),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDE5DF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 19,
      height: 19,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .22
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -1.57, 3.14, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 1.57, 1.57, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 0, .78, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), .78, .79, false, paint);
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s * .28,
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(s * .5, s * .38, s * .45, s * .24),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
