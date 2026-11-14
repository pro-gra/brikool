import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/brikool_locale.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/moroccan_cities.dart';

// ── palette ──────────────────────────────────────────────────────────
const _ink     = Color(0xFF0D1117);
const _sub     = Color(0xFF6E7781);
const _muted   = Color(0xFFB0B8BF);
const _border  = Color(0xFFE6E9EC);
const _bg      = Color(0xFFF8F9FA);
const _white   = Color(0xFFFFFFFF);
const _green   = Color(0xFF1A7A45);
const _greenBg = Color(0xFFECF7F1);
const _danger  = Color(0xFFCF2020);

// ════════════════════════════════════════════════════════════════════
class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({super.key});
  @override
  State<ClientOnboardingScreen> createState() => _State();
}

class _State extends State<ClientOnboardingScreen>
    with TickerProviderStateMixin {
  final _fs      = FirestoreService();
  final _storage = StorageService();
  final _picker  = ImagePicker();
  final _nameCtrl = TextEditingController();

  Uint8List? _photoBytes;
  XFile?     _photoFile;
  String?    _city;
  String?    _referral;
  bool       _saving = false;
  String?    _error;

  // entrance animation
  late final AnimationController _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _heroFade =
      CurvedAnimation(parent: _enterCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOut));
  late final Animation<Offset> _heroSlide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
          .animate(CurvedAnimation(parent: _enterCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOutCubic)));
  late final Animation<double> _formFade =
      CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.3, 1, curve: Curves.easeOut));
  late final Animation<Offset> _formSlide =
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
          .animate(CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic)));

  static const _refs = [
    ('صاحبي / عيلتي', '👥'),
    ('فيسبوك / إنستا', '📱'),
    ('تيكتوك', '🎵'),
    ('غوغل', '🔍'),
    ('فالزنقة', '🏙️'),
    ('حاجة أخرى', '✨'),
  ];

  bool get _canSubmit =>
      _nameCtrl.text.trim().length >= 2 && _city != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 78);
      if (f == null) return;
      final b = await f.readAsBytes();
      if (!mounted) return;
      setState(() { _photoFile = f; _photoBytes = b; });
    } catch (_) {}
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _error = 'انتهات الجلسة. عاود الدخول.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      String? photoUrl;
      if (_photoFile != null && _photoBytes != null) {
        try {
          photoUrl = await _storage.upload(
            path: 'users/${user.uid}/profile.jpg',
            localPathOrIgnoredOnWeb: _photoFile!.path,
            bytes: _photoBytes!, contentType: 'image/jpeg',
          ).timeout(const Duration(seconds: 15));
        } catch (_) {}
      }
      await _fs.updateUserProfile(user.uid,
        fullName: _nameCtrl.text.trim(),
        photoUrl: photoUrl,
        city: _city,
        referralSource: _referral,
        clientOnboardingComplete: true,
      );
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'فشل الحفظ. عاود حاول.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // ── decorative top arc ──────────────────────────────────────
        Positioned(
          top: -80, left: -60,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          top: -20, right: -40,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withOpacity(0.04),
            ),
          ),
        ),
        // ── content ─────────────────────────────────────────────────
        SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              SliverToBoxAdapter(child: _buildForm()),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildCta(),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── hero section ─────────────────────────────────────────────────
  Widget _buildHero() {
    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Align(alignment: AlignmentDirectional.centerEnd, child: BrikoolLanguagePicker(compact: true)),
            const SizedBox(height: 16),
            // logo pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _greenBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7,
                    decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                const Text('brikool',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _green)),
              ]),
            ),
            const SizedBox(height: 22),
            // headline
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                    color: _ink, height: 1.1, letterSpacing: -0.8),
                children: [
                  TextSpan(text: 'مرحباً\n'),
                  TextSpan(text: 'بك فبريكول 👋',
                      style: TextStyle(color: _green)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'دقيقة وحدة — ومن بعد يبدا الخير.',
              style: TextStyle(fontSize: 15, color: _sub, height: 1.5),
            ),
            const SizedBox(height: 32),
            // ── avatar picker ────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _pickPhoto,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_photoBytes != null),
                  tween: Tween(begin: 0.75, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Stack(children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _greenBg,
                        border: Border.all(
                          color: _photoBytes != null ? _green : _border,
                          width: _photoBytes != null ? 3 : 1.5,
                        ),
                        image: _photoBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_photoBytes!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _photoBytes == null
                          ? const Icon(Icons.add_a_photo_outlined, color: _green, size: 30)
                          : null,
                    ),
                    Positioned(bottom: 3, right: 3,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: _green, shape: BoxShape.circle,
                          border: Border.all(color: _white, width: 2.5),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 14, color: _white),
                      )),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('الصورة — اختيارية',
                style: TextStyle(fontSize: 12, color: _muted))),
          ]),
        ),
      ),
    );
  }

  // ── form ─────────────────────────────────────────────────────────
  Widget _buildForm() {
    return FadeTransition(
      opacity: _formFade,
      child: SlideTransition(
        position: _formSlide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── name ───────────────────────────────────────────────
            _SectionLabel('سميتك الكاملة *'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _nameCtrl.text.trim().length >= 2
                    ? _green : _border),
                boxShadow: _nameCtrl.text.trim().length >= 2 ? [
                  BoxShadow(color: _green.withOpacity(0.08),
                      blurRadius: 10, offset: const Offset(0, 4))
                ] : [],
              ),
              child: TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _ink),
                decoration: InputDecoration(
                  hintText: 'مثال: يوسف العلامي',
                  hintStyle: const TextStyle(fontSize: 15, color: _muted),
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      key: ValueKey(_nameCtrl.text.trim().length >= 2),
                      _nameCtrl.text.trim().length >= 2
                          ? Icons.check_circle_outline_rounded
                          : Icons.badge_outlined,
                      size: 20,
                      color: _nameCtrl.text.trim().length >= 2 ? _green : _muted,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── city ───────────────────────────────────────────────
            _SectionLabel('المدينة *'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _saving ? null : () async {
                final c = await showCityPicker(context, current: _city);
                if (c != null && mounted) setState(() { _city = c; _error = null; });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _city != null ? _green : _border),
                  boxShadow: _city != null ? [
                    BoxShadow(color: _green.withOpacity(0.08),
                        blurRadius: 10, offset: const Offset(0, 4))
                  ] : [],
                ),
                child: Row(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      key: ValueKey(_city != null),
                      _city != null ? Icons.check_circle_outline_rounded
                                    : Icons.location_city_outlined,
                      size: 20,
                      color: _city != null ? _green : _muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _city ?? 'اختار المدينة...',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _city != null ? _ink : _muted,
                    ),
                  )),
                  const Icon(Icons.expand_more_rounded, color: _muted, size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // ── referral chips ────────────────────────────────────
            _SectionLabel('كيفاش عرفتينا؟ (اختياري)'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: _refs.map((r) {
                final (label, emoji) = r;
                final sel = _referral == label;
                return GestureDetector(
                  onTap: _saving ? null : () => setState(() =>
                      _referral = sel ? null : label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? _green : _white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: sel ? _green : _border),
                      boxShadow: sel ? [
                        BoxShadow(color: _green.withOpacity(0.18),
                            blurRadius: 8, offset: const Offset(0, 3))
                      ] : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(label, style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700,
                        color: sel ? _white : _ink,
                      )),
                    ]),
                  ),
                );
              }).toList(),
            ),

            // ── error ─────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _danger.withOpacity(0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: _danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(fontSize: 13, color: _danger))),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── CTA ──────────────────────────────────────────────────────────
  Widget _buildCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        // submit button
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: _canSubmit ? _green : _border,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _canSubmit ? [
              BoxShadow(color: _green.withOpacity(0.28),
                  blurRadius: 20, offset: const Offset(0, 8))
            ] : [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: (_canSubmit && !_saving) ? _submit : null,
              borderRadius: BorderRadius.circular(18),
              child: Center(child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _saving
                    ? const SizedBox(key: ValueKey('l'), width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: _white))
                    : Row(key: const ValueKey('t'),
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(
                          _canSubmit ? '🚀 يالاه نبداو' : 'عمّر كل الحقول الواجبة',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: _canSubmit ? _white : _muted,
                          ),
                        ),
                      ]),
              )),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // progress pills — visual feedback on what's filled
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Pill(done: _nameCtrl.text.trim().length >= 2, label: 'السمية'),
          const SizedBox(width: 8),
          _Pill(done: _city != null, label: 'المدينة'),
          const SizedBox(width: 8),
          _Pill(done: _referral != null, label: 'المصدر', optional: true),
        ]),
        const SizedBox(height: 12),
        const Text('معلوماتك سرية ومحمية 🔒',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: _muted)),
      ]),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
          color: _sub, letterSpacing: 0.1));
}

// ── Progress pill ─────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill({required this.done, required this.label, this.optional = false});
  final bool done;
  final String label;
  final bool optional;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? _greenBg : optional ? _bg : _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: done ? _green.withOpacity(0.4) : _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            key: ValueKey(done),
            done ? Icons.check_rounded : (optional ? Icons.radio_button_unchecked : Icons.circle_outlined),
            size: 12,
            color: done ? _green : optional ? _muted : _muted,
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                color: done ? _green : _muted)),
      ]),
    );
  }
}