import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/auth_service.dart';
import 'otp_verify_screen.dart';
import 'email_auth_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  bool _isArabic = false;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  static const Color _green = Color(0xFF087A4B);
  static const Color _deepGreen = Color(0xFF063D2B);
  static const Color _ink = Color(0xFF17251E);
  static const Color _muted = Color(0xFF718078);
  static const Color _line = Color(0xFFE7ECE8);

  String _t(String fr, String ar) => _isArabic ? ar : fr;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final number = _phoneController.text.trim();
    if (number.length != 9) {
      setState(() => _error = _t(
        'Entrez un numéro marocain valide à 9 chiffres.',
        'يرجى إدخال رقم هاتف مغربي صحيح من 9 أرقام.',
      ));
      return;
    }

    final phone = '+212$number';
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    await _authService.sendOtp(
      phoneNumber: phone,
      onCodeSent: () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            authService: _authService,
            phoneNumber: phone,
          ),
        ));
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

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
      if (mounted) setState(() => _googleLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _googleLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _email() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmailAuthScreen(authService: _authService),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F2),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8FAF8),
                      Color(0xFFEDF3EF),
                      Color(0xFFF5F7F5),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -150,
              right: -105,
              child: Container(
                width: 390,
                height: 390,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B8050).withOpacity(.075),
                ),
              ),
            ),
            Positioned(
              bottom: -190,
              left: -130,
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9ABBA6).withOpacity(.13),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B8050), Color(0xFF9CC8AD)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 850;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: desktop ? 32 : 20,
                            vertical: desktop ? 34 : 18,
                          ),
                          child: desktop
                              ? _desktopLayout()
                              : _mobileLayout(),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageSwitch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _languageOption('FR', false),
        _languageOption('ع', true),
      ]),
    );
  }

  Widget _languageOption(String label, bool arabic) {
    final selected = _isArabic == arabic;
    return GestureDetector(
      onTap: () => setState(() {
        _isArabic = arabic;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? _deepGreen : _muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        )),
      ),
    );
  }

  Widget _mobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _languageSwitch(),
        ),
        const SizedBox(height: 18),
        _mobileIntro(),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _loginCard(compact: true),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _t('BRIKOOL  •  ESPACE CLIENT', 'بريكول  •  فضاء الزبناء'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF84948A),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _mobileIntro() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 27),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073F2D), Color(0xFF0B8051)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -25,
            top: -35,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(.10), width: 18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('ESPACE CLIENT', 'فضاء الزبناء'),
                style: const TextStyle(
                  color: Color(0xFFB9D8C8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                _t('Connexion', 'تسجيل الدخول'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t('Retrouvez vos services et vos demandes.',
                    'تابع خدماتك وطلباتك بسهولة.'),
                style: const TextStyle(
                  color: Color(0xFFD7E9DF),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileHeader() {
    return const SizedBox.shrink();
  }

  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 54),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('ESPACE CLIENT', 'فضاء الزبناء'),
                  style: const TextStyle(
                    color: _green,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t('Connectez-vous à votre compte.',
                      'سجّل الدخول إلى حسابك.'),
                  style: const TextStyle(
                    color: _deepGreen,
                    fontSize: 43,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _t('Gérez vos demandes et retrouvez les professionnels qui vous accompagnent.',
                      'تابع طلباتك وتواصل مع المهنيين الذين يقدمون لك الخدمات.'),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 28),
                _trustLine(Icons.verified_outlined,
                    _t('Un parcours simple et sécurisé', 'تجربة سهلة وآمنة')),
                const SizedBox(height: 13),
                _trustLine(Icons.location_on_outlined,
                    _t('Des services près de chez vous', 'خدمات قريبة منك')),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _languageSwitch(),
              ),
              const SizedBox(height: 18),
              _loginCard(compact: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopLanguageOption(String label, bool arabic) {
    return _languageOption(label, arabic);
  }

  Widget _brandMark() {
    return const SizedBox.shrink();
  }

  Widget _trustLine(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F0E8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _green, size: 18),
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF405148),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _loginCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 22 : 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EBE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17172F22),
            blurRadius: 48, offset: Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _t('Connexion', 'تسجيل الدخول'),
            style: const TextStyle(
              color: _ink, fontSize: 26,
              fontWeight: FontWeight.w900, letterSpacing: -.55,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t('Connectez-vous ou créez votre compte pour continuer.',
                'سجّل الدخول أو أنشئ حسابك للمتابعة.'),
            style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 25),
          Text(
            _t('NUMÉRO DE TÉLÉPHONE', 'رقم الهاتف'),
            textAlign: _isArabic ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF59675F), fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: .9,
            ),
          ),
          const SizedBox(height: 9),
          _phoneField(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(
              color: Color(0xFFB42318), fontSize: 12, height: 1.4,
            )),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_t('Continuer avec mon numéro', 'المتابعة برقم الهاتف'),
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(width: 8),
                        Icon(_isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Divider(color: _line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_t('OU', 'أو'), style: const TextStyle(
                color: Color(0xFF9AA49D), fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1,
              )),
            ),
            const Expanded(child: Divider(color: _line)),
          ]),
          const SizedBox(height: 17),
          _socialButton(
            label: _t('Continuer avec Google', 'المتابعة باستخدام Google'),
            icon: const _GoogleMark(),
            onPressed: _googleLoading ? null : _google,
            loading: _googleLoading,
          ),
          const SizedBox(height: 10),
          _socialButton(
            label: _t('Continuer avec e-mail', 'المتابعة بالبريد الإلكتروني'),
            icon: const Icon(Icons.mail_outline_rounded, size: 18, color: _ink),
            onPressed: _email,
          ),
          const SizedBox(height: 19),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF87948B)),
            const SizedBox(width: 6),
            Flexible(child: Text(
              _t('Connexion sécurisée · Vos données restent protégées',
                  'اتصال آمن · بياناتك محمية'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF87948B), fontSize: 10.5),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _phoneField() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _error == null ? const Color(0xFFDCE5DE) : const Color(0xFFB42318),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('🇲🇦', style: TextStyle(fontSize: 18)),
            SizedBox(width: 7),
            Text('+212', style: TextStyle(
              color: _ink, fontSize: 14, fontWeight: FontWeight.w800,
            )),
          ]),
        ),
        Container(width: 1, height: 25, color: _line),
        Expanded(child: TextField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
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
            color: _ink, fontSize: 15, fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          decoration: InputDecoration(
            hintText: '6XX XXX XXX',
            hintStyle: const TextStyle(color: Color(0xFFADB7B0), fontSize: 13),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            isDense: true,
          ),
        )),
      ]),
    );
  }

  Widget _socialButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    return SizedBox(
      height: 49,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDE5DF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _green),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 9),
                  Flexible(child: Text(label, style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700,
                  ))),
                ],
              ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text('G', style: TextStyle(
      color: Color(0xFF4285F4), fontSize: 19, fontWeight: FontWeight.w900,
    ));
  }
}
