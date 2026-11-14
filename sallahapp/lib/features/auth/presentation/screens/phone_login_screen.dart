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
        backgroundColor: const Color(0xFFF5F7F5),
        body: SafeArea(
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
      ),
    );
  }

  Widget _languageSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(.2)),
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
          color: selected ? _deepGreen : Colors.white,
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
        _mobileHeader(),
        Transform.translate(
          offset: const Offset(0, -22),
          child: _loginCard(compact: true),
        ),
        Transform.translate(
          offset: const Offset(0, -8),
          child: Text(
            _t('BRIKOOL · LES BONS PROFESSIONNELS, EN TOUTE SIMPLICITÉ',
                'بريكول · مهنيون موثوقون، بكل سهولة'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF929E96),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileHeader() {
    return Container(
      height: 218,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 38),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D8051), Color(0xFF06432F)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _brandMark(),
            const SizedBox(width: 10),
            const Text('brikool', style: TextStyle(
              color: Colors.white, fontSize: 23,
              fontWeight: FontWeight.w900, letterSpacing: -.8,
            )),
            const Spacer(),
            _languageSwitch(),
          ]),
          const Spacer(),
          Text(
            _t('Votre maison, entre de bonnes mains.',
                'دارك بين يدي أمينة.'),
            style: const TextStyle(
              color: Colors.white, fontSize: 25,
              height: 1.2, fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t('Les professionnels qu’il vous faut, simplement.',
                'المهنيون اللي محتاج ليهم، بكل سهولة.'),
            style: const TextStyle(
              color: Color(0xFFD6E9DE), fontSize: 12.5, height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  _brandMark(),
                  const SizedBox(width: 12),
                  const Text('brikool', style: TextStyle(
                    color: _ink, fontSize: 27,
                    fontWeight: FontWeight.w900, letterSpacing: -1,
                  )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EFEB),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(children: [
                      _desktopLanguageOption('FR', false),
                      _desktopLanguageOption('ع', true),
                    ]),
                  ),
                ]),
                const SizedBox(height: 64),
                Text(
                  _t('Les bons pros.\\nAu bon moment.',
                      'المهنيون المناسبون.\\nفي الوقت المناسب.'),
                  style: const TextStyle(
                    color: _deepGreen, fontSize: 48,
                    height: 1.12, fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t('Un dépannage, une installation ou un projet à la maison ? '
                      'Trouvez le professionnel qu’il vous faut sur Brikool.',
                      'تحتاج إلى إصلاح أو تركيب أو خدمة في منزلك؟ '
                      'اعثر على المهني المناسب عبر بريكول.'),
                  style: const TextStyle(
                    color: _muted, fontSize: 16, height: 1.7,
                  ),
                ),
                const SizedBox(height: 34),
                _trustLine(Icons.verified_outlined,
                    _t('Des professionnels de confiance', 'مهنيون موثوقون')),
                const SizedBox(height: 17),
                _trustLine(Icons.bolt_outlined,
                    _t('Une demande en quelques clics', 'اطلب خدمتك في خطوات بسيطة')),
                const SizedBox(height: 17),
                _trustLine(Icons.home_outlined,
                    _t('Des services près de chez vous', 'خدمات قريبة منك')),
              ],
            ),
          ),
        ),
        SizedBox(width: 430, child: _loginCard(compact: false)),
      ],
    );
  }

  Widget _desktopLanguageOption(String label, bool arabic) {
    final selected = _isArabic == arabic;
    return GestureDetector(
      onTap: () => setState(() {
        _isArabic = arabic;
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? _deepGreen : _muted,
          fontSize: 12, fontWeight: FontWeight.w800,
        )),
      ),
    );
  }

  Widget _brandMark() {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: _green, borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 22),
    );
  }

  Widget _trustLine(IconData icon, String label) {
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F1EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _green, size: 18),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(
        color: Color(0xFF405148), fontSize: 14, fontWeight: FontWeight.w600,
      )),
    ]);
  }

  Widget _loginCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10172F22),
            blurRadius: 35, offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _t('Bienvenue sur Brikool', 'مرحباً بك في بريكول'),
            style: const TextStyle(
              color: _ink, fontSize: 23,
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
      height: 57,
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFB),
        border: Border.all(
          color: _error == null ? const Color(0xFFDCE5DE) : const Color(0xFFB42318),
        ),
        borderRadius: BorderRadius.circular(12),
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
