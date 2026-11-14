import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/brikool_locale.dart';
import '../../../../core/services/auth_service.dart';
import 'otp_verify_screen.dart';
import 'email_auth_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  bool _focused = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawNumber = _phoneController.text.trim();
    if (rawNumber.isEmpty) {
      setState(() => _error = BrikoolLocale.text('Veuillez entrer votre numéro de téléphone.', ar: 'يرجى إدخال رقم هاتفك.', darija: 'دخل رقم التيليفون ديالك عافاك.'));
      return;
    }
    if (rawNumber.length != 9) {
      setState(() => _error = BrikoolLocale.text('Veuillez entrer un numéro marocain valide.', ar: 'يرجى إدخال رقم مغربي صحيح.', darija: 'دخل رقم مغربي صحيح عافاك.'));
      return;
    }
    final e164 = '+212$rawNumber';
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    await _authService.sendOtp(
      phoneNumber: e164,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            authService: _authService, phoneNumber: e164),
        ));
      },
      onError: (message) {
        if (!mounted) return;
        setState(() { _loading = false; _error = message; });
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _googleLoading = true; _error = null; });
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null && mounted) {
        setState(() => _googleLoading = false); // user cancelled
      }
      // On success, auth state change navigates automatically.
    } catch (e) {
      if (mounted) {
        setState(() {
          _googleLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _openEmail() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmailAuthScreen(authService: _authService),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                isWide ? 32 : 22,
                isWide ? 28 : 18,
                isWide ? 32 : 22,
                bottomInset > 0 ? bottomInset + 24 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 46),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _BrandMark(),
                        const Spacer(),
                        const BrikoolLanguagePicker(compact: true),
                      ],
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Container(
                              padding: EdgeInsets.all(isWide ? 34 : 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: const Color(0xFFE7ECE8)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF173D2A).withOpacity(.055),
                                    blurRadius: 36,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    BrikoolLocale.text('Connectez-vous', ar: 'تسجيل الدخول', darija: 'دخل لحسابك'),
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                      fontSize: 27,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.8,
                                      color: Color(0xFF17231B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    BrikoolLocale.text(
                                      'Accédez à votre espace Brikool en quelques secondes.',
                                      ar: 'ادخل إلى حسابك في بريكول في ثوانٍ.',
                                      darija: 'دخل لحسابك فبريكول غير فثواني.',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Color(0xFF748078),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    BrikoolLocale.text('Numéro de téléphone', ar: 'رقم الهاتف', darija: 'رقم التيليفون'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF344139),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFBFA),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _error != null
                                            ? AppColors.danger
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
                                              Text('🇲🇦', style: TextStyle(fontSize: 19)),
                                              SizedBox(width: 7),
                                              Text(
                                                '+212',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF344139),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(width: 1, height: 26, color: const Color(0xFFE0E6E1)),
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
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.1,
                                              color: Color(0xFF1D2921),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: '6XX XXX XXX',
                                              hintStyle: TextStyle(
                                                fontSize: 15,
                                                color: Colors.blueGrey.shade200,
                                                letterSpacing: .6,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                            ),
                                            onChanged: (_) {
                                              if (_error != null) setState(() => _error = null);
                                            },
                                            onSubmitted: (_) => _submit(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 180),
                                    child: _error == null
                                        ? const SizedBox.shrink()
                                        : Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.error_outline_rounded,
                                                    size: 15, color: AppColors.danger),
                                                const SizedBox(width: 7),
                                                Expanded(
                                                  child: Text(
                                                    _error!,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      height: 1.4,
                                                      color: AppColors.danger,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        disabledBackgroundColor: AppColors.primary.withOpacity(.65),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 160),
                                        child: _loading
                                            ? const SizedBox(
                                                key: ValueKey('loading'),
                                                width: 21,
                                                height: 21,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.3,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Row(
                                                key: const ValueKey('send-code'),
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    BrikoolLocale.text('Continuer', ar: 'متابعة', darija: 'كمل'),
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 9),
                                                  const Icon(Icons.arrow_forward_rounded, size: 18),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider(color: Color(0xFFE5EAE6))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 13),
                                        child: Text(
                                          BrikoolLocale.text('OU', ar: 'أو', darija: 'ولا'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            letterSpacing: .8,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9AA49D),
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider(color: Color(0xFFE5EAE6))),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  _SocialButton(
                                    onTap: _googleLoading ? null : _signInWithGoogle,
                                    loading: _googleLoading,
                                    label: BrikoolLocale.text(
                                      'Continuer avec Google',
                                      ar: 'المتابعة باستخدام Google',
                                      darija: 'كمل بـ Google',
                                    ),
                                    icon: _GoogleIcon(),
                                  ),
                                  const SizedBox(height: 11),
                                  _SocialButton(
                                    onTap: _openEmail,
                                    loading: false,
                                    label: BrikoolLocale.text(
                                      'Continuer avec e-mail',
                                      ar: 'المتابعة بالبريد الإلكتروني',
                                      darija: 'كمل بالإيميل',
                                    ),
                                    icon: const Icon(
                                      Icons.mail_outline_rounded,
                                      size: 19,
                                      color: Color(0xFF344139),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock_outline_rounded,
                                          size: 14, color: AppColors.primary),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          BrikoolLocale.text(
                                            'Connexion sécurisée · Votre numéro reste privé',
                                            ar: 'اتصال آمن · رقمك يبقى سرياً',
                                            darija: 'دخول آمن · رقمك كيبقى سري',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF87928A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 22),
                    Text(
                      'brikool  ·  Les services, simplement.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9AA49D),
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Social button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon,
      required this.loading, required this.onTap});
  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E7E2), width: 1.3),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          else ...[
            icon,
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF252D27))),
          ],
        ]),
      ),
    );
  }
}

// ── Google SVG icon ───────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20, height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Blue
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -1.57, 3.14, false,
        Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = s * 0.22);
    // Red
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 1.57, 1.57, false,
        Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = s * 0.22);
    // Yellow
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 0, 0.78, false,
        Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = s * 0.22);
    // Green
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 0.78, 0.79, false,
        Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = s * 0.22);
    // White center fill + horizontal bar
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.28,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawRect(Rect.fromLTWH(s * 0.5, s * 0.38, s * 0.45, s * 0.24),
        Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── Brand mark ────────────────────────────────────────────────────────────────

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 40, height: 40,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5EBE6)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.asset('assets/images/brikol_app_icon_192.png', fit: BoxFit.contain),
        ),
      ),
      const SizedBox(width: 9),
      const Text('brikool',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: Color(0xFF182019))),
    ]);
  }
}
