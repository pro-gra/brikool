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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Background decoration ─────────────────────────────────
          Positioned(top: -120, right: -90,
              child: _GlowCircle(size: 300, color: AppColors.primary.withOpacity(0.10))),
          Positioned(top: 210, left: -130,
              child: _GlowCircle(size: 260, color: AppColors.primary.withOpacity(0.045))),

          // ── Main content ──────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 18, 24,
                  bottomInset > 0 ? bottomInset + 20 : 28),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Brand bar ───────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BrandMark(),
                          const Spacer(),
                          const BrikoolLanguagePicker(compact: true),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFFE7ECE8)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 7, height: 7,
                                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('Service local',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF526057))),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),

                      // ── Logo ───────────────────────────────────────
                      Center(
                        child: Container(
                          width: 94, height: 94,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.20),
                                blurRadius: 30, offset: const Offset(0, 14))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset('assets/images/brikol_app_icon_192.png',
                                width: 94, height: 94, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Welcome ────────────────────────────────────
                      Center(
                        child: Text(BrikoolLocale.text('Bienvenue sur brikool', ar: 'مرحباً بك في بريكول', darija: 'مرحبا بيك فبريكول'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w900,
                                letterSpacing: -0.8, color: Color(0xFF17201A))),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(BrikoolLocale.text('Des professionnels fiables,\ndirectement à votre porte.', ar: 'محترفون موثوقون، مباشرة إلى باب منزلك.', darija: 'تقنيين ثقة، حتى لباب دارك.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF707A73), fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 40),

                      // ── Phone card ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE8EDE9)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035),
                              blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(BrikoolLocale.text('Votre numéro de téléphone', ar: 'رقم هاتفك', darija: 'رقم التيليفون ديالك'),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF252D27))),
                          const SizedBox(height: 8),
                          Text(BrikoolLocale.text('Nous vous enverrons un code de vérification par SMS.', ar: 'سنرسل إليك رمز التحقق عبر رسالة SMS.', darija: 'غادي نصيفطو ليك كود التأكيد فـ SMS.'),
                              style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF89918B))),
                          const SizedBox(height: 18),
                          // Phone field
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAF8),
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: _error != null ? AppColors.danger
                                    : _focused ? AppColors.primary : const Color(0xFFE1E7E2),
                                width: _focused || _error != null ? 1.7 : 1.1,
                              ),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13),
                                height: 58,
                                child: const Row(children: [
                                  Text('🇲🇦', style: TextStyle(fontSize: 21)),
                                  SizedBox(width: 7),
                                  Text('+212', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF26302A))),
                                ]),
                              ),
                              Container(width: 1, height: 28, color: const Color(0xFFDCE3DE)),
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
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                                      letterSpacing: 1.7, color: Color(0xFF1D261F)),
                                  decoration: const InputDecoration(
                                    hintText: '6XX XXX XXX',
                                    hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
                                        letterSpacing: 1.3, color: Color(0xFFB2BAB4)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14),
                                  ),
                                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                                  onSubmitted: (_) => _submit(),
                                ),
                              ),
                            ]),
                          ),
                          // Error
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            child: _error != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
                                      const SizedBox(width: 7),
                                      Expanded(child: Text(_error!,
                                          style: const TextStyle(fontSize: 12, height: 1.4,
                                              color: AppColors.danger, fontWeight: FontWeight.w600))),
                                    ]))
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 18),
                          // Send OTP button
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.primary.withOpacity(0.65),
                                foregroundColor: Colors.white, elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _loading
                                    ? const SizedBox(key: ValueKey('l'), width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Row(key: ValueKey('b'),
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(BrikoolLocale.text('Recevoir le code', ar: 'تلقي الرمز', darija: 'توصل بالكود'),
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                          SizedBox(width: 9),
                                          Icon(Icons.arrow_forward_rounded, size: 19),
                                        ]),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 18),

                      // ── Divider "ou" ───────────────────────────────
                      Row(children: [
                        const Expanded(child: Divider(color: Color(0xFFDCE3DE))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(BrikoolLocale.text('ou', ar: 'أو', darija: 'ولا'), style: TextStyle(fontSize: 13, color: Color(0xFF89918B), fontWeight: FontWeight.w600)),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFDCE3DE))),
                      ]),
                      const SizedBox(height: 16),

                      // ── Google button ──────────────────────────────
                      _SocialButton(
                        onTap: _googleLoading ? null : _signInWithGoogle,
                        loading: _googleLoading,
                        label: BrikoolLocale.text('Continuer avec Google', ar: 'المتابعة باستخدام Google', darija: 'كمل بـ Google'),
                        icon: _GoogleIcon(),
                      ),
                      const SizedBox(height: 12),

                      // ── Email button ───────────────────────────────
                      _SocialButton(
                        onTap: _openEmail,
                        loading: false,
                        label: BrikoolLocale.text('Continuer avec e-mail', ar: 'المتابعة بالبريد الإلكتروني', darija: 'كمل بالإيميل'),
                        icon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF3D4A41)),
                      ),
                      const SizedBox(height: 24),

                      // ── Security note ──────────────────────────────
                      Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(BrikoolLocale.text('Votre numéro reste privé et sécurisé', ar: 'رقمك محمي وسري', darija: 'رقمك باقي سري ومحمي'),
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF89918B))),
                        ]),
                      ),
                      const SizedBox(height: 28),

                      // ── Tagline ────────────────────────────────────
                      Center(
                        child: Column(children: const [
                          Text('خدمة نقية... فبلاصتك',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6F7972))),
                          SizedBox(height: 6),
                          Text('brikool',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                  color: Color(0xFFB0B8B2), letterSpacing: 1)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

// ── Glow circle ───────────────────────────────────────────────────────────────

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}