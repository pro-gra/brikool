import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_service.dart';

/// Single screen that handles both sign-in and sign-up with email/password,
/// plus a "forgot password" flow — all animated in place.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, required this.authService});
  final AuthService authService;
  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

enum _Mode { signIn, signUp, reset }

class _EmailAuthScreenState extends State<EmailAuthScreen>
    with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.signIn;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320))
        ..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _confirmCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _switchMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _success = null;
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    });
    _anim.forward(from: 0);
  }

  Future<void> _submit() async {
    setState(() { _error = null; _success = null; _loading = true; });
    FocusScope.of(context).unfocus();
    try {
      if (_mode == _Mode.reset) {
        if (_emailCtrl.text.trim().isEmpty) {
          setState(() { _error = 'Entrez votre adresse e-mail.'; _loading = false; });
          return;
        }
        await widget.authService.sendPasswordReset(_emailCtrl.text.trim());
        setState(() {
          _success = 'Un e-mail de réinitialisation a été envoyé à ${_emailCtrl.text.trim()}.';
          _loading = false;
        });
        return;
      }

      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      if (email.isEmpty || password.isEmpty) {
        setState(() { _error = 'Veuillez remplir tous les champs.'; _loading = false; });
        return;
      }

      if (_mode == _Mode.signUp) {
        if (_nameCtrl.text.trim().isEmpty) {
          setState(() { _error = 'Entrez votre nom complet.'; _loading = false; });
          return;
        }
        if (password != _confirmCtrl.text) {
          setState(() { _error = 'Les mots de passe ne correspondent pas.'; _loading = false; });
          return;
        }
        if (password.length < 6) {
          setState(() { _error = 'Le mot de passe doit contenir au moins 6 caractères.'; _loading = false; });
          return;
        }
        await widget.authService.createAccountWithEmail(
          email: email, password: password, displayName: _nameCtrl.text.trim());
      } else {
        await widget.authService.signInWithEmail(email: email, password: password);
      }
      // Auth state change handled by root navigator — no need to pop manually.
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReset = _mode == _Mode.reset;
    final isSignUp = _mode == _Mode.signUp;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF17201A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, 8, 24,
              MediaQuery.of(context).viewInsets.bottom + 28),
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ────────────────────────────────────────────
                Text(
                  isReset
                      ? 'Mot de passe oublié'
                      : isSignUp
                          ? 'Créer un compte'
                          : 'Connexion par e-mail',
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900,
                    letterSpacing: -0.6, color: Color(0xFF17201A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isReset
                      ? 'Entrez votre e-mail pour recevoir un lien de réinitialisation.'
                      : isSignUp
                          ? 'Rejoignez brikool et trouvez des pros fiables.'
                          : 'Connectez-vous à votre compte brikool.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF707A73), height: 1.4),
                ),
                const SizedBox(height: 30),

                // ── Card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE8EDE9)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.035),
                          blurRadius: 30, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name (sign-up only)
                      if (isSignUp) ...[
                        _Label('Nom complet'),
                        _Field(
                          controller: _nameCtrl,
                          hint: 'Votre nom et prénom',
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Email
                      _Label('Adresse e-mail'),
                      _Field(
                        controller: _emailCtrl,
                        hint: 'exemple@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      // Password fields (not in reset mode)
                      if (!isReset) ...[
                        const SizedBox(height: 14),
                        _Label('Mot de passe'),
                        _Field(
                          controller: _passwordCtrl,
                          hint: isSignUp ? 'Min. 6 caractères' : '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20, color: const Color(0xFF89918B)),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ],
                      if (isSignUp) ...[
                        const SizedBox(height: 14),
                        _Label('Confirmer le mot de passe'),
                        _Field(
                          controller: _confirmCtrl,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: true,
                        ),
                      ],
                      // Forgot password (sign-in only)
                      if (_mode == _Mode.signIn) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _switchMode(_Mode.reset),
                            child: const Text('Mot de passe oublié ?',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                        ),
                      ],
                      // Error / success
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _Banner(text: _error!, isError: true),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: 12),
                        _Banner(text: _success!, isError: false),
                      ],
                      const SizedBox(height: 20),
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _loading
                                ? const SizedBox(key: ValueKey('l'), width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(
                                    key: const ValueKey('t'),
                                    isReset ? 'Envoyer le lien' : isSignUp ? 'Créer mon compte' : 'Se connecter',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // ── Mode switcher ─────────────────────────────────────
                if (_mode != _Mode.reset)
                  Center(
                    child: GestureDetector(
                      onTap: () => _switchMode(isSignUp ? _Mode.signIn : _Mode.signUp),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF89918B)),
                          children: [
                            TextSpan(text: isSignUp ? 'Vous avez déjà un compte ? ' : 'Pas encore de compte ? '),
                            TextSpan(
                              text: isSignUp ? 'Se connecter' : 'Créer un compte',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_mode == _Mode.reset)
                  Center(
                    child: GestureDetector(
                      onTap: () => _switchMode(_Mode.signIn),
                      child: const Text('← Retour à la connexion',
                          style: TextStyle(fontSize: 13.5, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF252D27))),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E7E2), width: 1.1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1D261F)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFB2BAB4), fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF89918B)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 16, color: isError ? AppColors.danger : AppColors.success),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600,
                color: isError ? AppColors.danger : AppColors.success))),
      ]),
    );
  }
}