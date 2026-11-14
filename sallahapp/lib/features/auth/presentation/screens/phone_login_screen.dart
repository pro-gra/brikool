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

  static const _ink = Color(0xFF17231B);
  static const _muted = Color(0xFF758078);
  static const _green = Color(0xFF0E8050);
  static const _line = Color(0xFFE5EBE6);

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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F4),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 820;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 36 : 20,
                vertical: isDesktop ? 28 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isDesktop ? 56 : 40),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(child: _BrandPanel()),
                              const SizedBox(width: 24),
                              Expanded(child: _buildLoginCard(compact: false)),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMobileBrand(),
                              const SizedBox(height: 22),
                              _buildLoginCard(compact: true),
                              const SizedBox(height: 20),
                              _buildFooter(),
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

  Widget _buildMobileBrand() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.home_repair_service_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        const Text(
          'brikool',
          style: TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.1,
          ),
        ),
        const Spacer(),
        const _MoroccoLabel(),
      ],
    );
  }

  Widget _buildLoginCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 22 : 38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF183B28).withOpacity(.055),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!compact) ...[
            Row(
              children: const [
                Text(
                  'brikool',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.8,
                  ),
                ),
                Spacer(),
                _MoroccoLabel(),
              ],
            ),
            const SizedBox(height: 38),
          ],
          const Text(
            'Ravi de vous revoir.',
            style: TextStyle(
              color: _ink,
              fontSize: 29,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Connectez-vous pour accéder à vos services et suivre vos demandes.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 30),
          const Text(
            'NUMÉRO DE TÉLÉPHONE',
            style: TextStyle(
              color: Color(0xFF526057),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: 9),
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
          const SizedBox(height: 15),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: _green.withOpacity(.65),
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continuer avec le téléphone',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 23),
          Row(
            children: const [
              Expanded(child: Divider(color: _line)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 13),
                child: Text(
                  'OU',
                  style: TextStyle(
                    color: Color(0xFF9AA49D),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: _line)),
            ],
          ),
          const SizedBox(height: 19),
          _SocialButton(
            label: 'Continuer avec Google',
            icon: const _GoogleIcon(),
            loading: _googleLoading,
            onTap: _googleLoading ? null : _signInWithGoogle,
          ),
          const SizedBox(height: 11),
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
          const SizedBox(height: 22),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 15,
                color: Color(0xFF7A887F),
              ),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Connexion sécurisée · Données protégées',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF89948D), fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _error != null
              ? const Color(0xFFB42318)
              : _focused
                  ? _green
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
                color: _ink,
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

  Widget _buildFooter() {
    return const Text(
      'LES SERVICES À DOMICILE, SIMPLEMENT.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFFA0AAA3),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 620),
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: const Color(0xFF0C3928),
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14583A), Color(0xFF092D20)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.16)),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'brikool',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(.14)),
            ),
            child: const Text(
              'VOTRE QUOTIDIEN, PLUS SIMPLE',
              style: TextStyle(
                color: Color(0xFFD6E9DC),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Les bons pros.\nAu bon moment.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 43,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Trouvez facilement des professionnels de confiance pour vos besoins à domicile.',
            style: TextStyle(
              color: Color(0xFFD0E0D5),
              fontSize: 15,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 34),
          const _BenefitRow(
            icon: Icons.verified_user_outlined,
            title: 'Des professionnels vérifiés',
            subtitle: 'Des profils pour choisir en confiance',
          ),
          const SizedBox(height: 20),
          const _BenefitRow(
            icon: Icons.bolt_outlined,
            title: 'Une demande en quelques instants',
            subtitle: 'Un parcours simple, sans complication',
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Colors.white.withOpacity(.72),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Pensé pour le Maroc',
                style: TextStyle(
                  color: Colors.white.withOpacity(.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFFD8EBDD), size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFBBD1C2),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoroccoLabel extends StatelessWidget {
  const _MoroccoLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F4),
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
