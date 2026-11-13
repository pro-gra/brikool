import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/technician_profile.dart';
import '../../../../models/technician_specialty.dart';
import '../../../../models/technician_skill.dart';
import '../../../../models/moroccan_cities.dart';

// ── Design Tokens (matches ClientOnboardingScreen) ───────────────────────────
const _kGreen     = Color(0xFF0D4A35);
const _kGreenL    = Color(0xFFECF7F1);
const _kInk       = Color(0xFF0F172A);
const _kMuted     = Color(0xFF64748B);
const _kBg        = Color(0xFFFAFBFC);
const _kCard      = Colors.white;
const _kBorder    = Color(0xFFE2E8F0);
const _kAmber     = Color(0xFFA65E00);
const _kAmberBg   = Color(0xFFFFF8EC);
const _kDanger    = Color(0xFFDC2626);
const _kDangerBg  = Color(0xFFFEF2F2);
const _kGold      = Color(0xFFF5C842);

// ── Step metadata ─────────────────────────────────────────────────────────────
const _kStepTitles = ['شكون أنت؟', 'سنك وخبرتك', 'عرّف بنفسك', 'تخصصاتك', 'مكانك', 'يالاه نبداو'];
const _kStepSubs   = [
  'سميتك والمدينة — واجبيين',
  'العمر وسنين الخبرة',
  'كلمة للعملاء عليك',
  'من 1 لـ 3 تخصصات',
  'باش نجيبوليك أقرب طلب',
  'راجع وأرسل',
];
const _kTotal = 6;

// ════════════════════════════════════════════════════════════════════════════════
class TechnicianOnboardingScreen extends StatefulWidget {
  const TechnicianOnboardingScreen({super.key});

  @override
  State<TechnicianOnboardingScreen> createState() => _TechState();
}

class _TechState extends State<TechnicianOnboardingScreen>
    with TickerProviderStateMixin {
  // ── services ─────────────────────────────────────────────────────────────────
  final _fs      = FirestoreService();
  final _storage = StorageService();
  final _picker  = ImagePicker();

  // ── step state ────────────────────────────────────────────────────────────────
  int _step = 0;

  // step 0
  XFile?     _photoFile;
  Uint8List? _photoBytes;
  final _nameCtrl = TextEditingController();
  String?    _city;

  // step 1
  final _ageCtrl = TextEditingController();
  int _years = 0;

  // step 2
  final _bioCtrl = TextEditingController();

  // step 3
  final List<_SpecDraft> _specs = [];

  // step 4
  Position? _pos;
  bool      _locTried = false;

  // step 5
  bool    _busy  = false;
  String? _error;

  // ── page transition ───────────────────────────────────────────────────────────
  late final AnimationController _pageCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late Animation<double> _pageFade =
      const AlwaysStoppedAnimation(1.0);
  late Animation<Offset> _pageSlide =
      const AlwaysStoppedAnimation(Offset.zero);

  // ── validation ────────────────────────────────────────────────────────────────
  bool get _ok0 => _nameCtrl.text.trim().isNotEmpty && _city != null;
  bool get _ok1 {
    final a = int.tryParse(_ageCtrl.text.trim());
    return a != null && a >= 18 && a <= 80;
  }
  bool get _ok2 => _bioCtrl.text.trim().length >= 20;
  bool get _ok3 => _specs.isNotEmpty && _specs.every((s) => s.isComplete);
  bool get _ok4 => _pos != null;
  bool _canProceed(int s) => switch (s) {
    0 => _ok0, 1 => _ok1, 2 => _ok2, 3 => _ok3, 4 => _ok4, _ => true
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _ageCtrl.addListener(() => setState(() {}));
    _bioCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    _pageCtrl.dispose();
    for (final s in _specs) s.dispose();
    super.dispose();
  }

  // ── navigation ────────────────────────────────────────────────────────────────
  void _go(int next) {
    HapticFeedback.lightImpact();
    final forward = next > _step;
    _pageFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut),
    );
    _pageSlide = Tween<Offset>(
      begin: Offset(forward ? 0.06 : -0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward(from: 0);
    setState(() => _step = next);
  }

  void _next() { if (_canProceed(_step) && _step < _kTotal - 1) _go(_step + 1); }
  void _back() { if (_step > 0) _go(_step - 1); }

  // ── photo ─────────────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    HapticFeedback.lightImpact();
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    final b = await f.readAsBytes();
    if (!mounted) return;
    setState(() { _photoFile = f; _photoBytes = b; });
  }

  // ── location ──────────────────────────────────────────────────────────────────
  Future<void> _locate() async {
    HapticFeedback.mediumImpact();
    setState(() { _locTried = true; _error = null; });
    try {
      Position? p;
      try {
        p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 15));
      } catch (_) {
        final perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          if (mounted) setState(() => _error = 'فعّل الـ GPS ومن بعد عاود حاول.');
          return;
        }
        p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 15));
      }
      if (mounted) setState(() { _pos = p; _error = null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'ما قدرناش نحددو بلاصتك. تحقق من الـ GPS.');
    }
  }

  // ── role switch ───────────────────────────────────────────────────────────────
  Future<void> _changeRole() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RoleSwitchSheet(),
    );
    if (ok != true || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': FieldValue.delete()});
  }

  // ── submit ────────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    HapticFeedback.mediumImpact();
    setState(() { _busy = true; _error = null; });

    try {
      String? photoUrl;
      if (_photoFile != null && _photoBytes != null) {
        try {
          photoUrl = await _storage.upload(
            path: 'technicians/${user.uid}/profile.jpg',
            localPathOrIgnoredOnWeb: _photoFile!.path,
            bytes: _photoBytes!,
            contentType: 'image/jpeg',
          ).timeout(const Duration(seconds: 15));
        } catch (_) {}
      }

      final specialties = <TechnicianSpecialty>[];
      for (final d in _specs) {
        String? dipUrl;
        if (d.dipFile != null && d.dipBytes != null) {
          try {
            dipUrl = await _storage.upload(
              path: 'technicians/${user.uid}/diploma_${d.skillId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
              localPathOrIgnoredOnWeb: d.dipFile!.path,
              bytes: d.dipBytes!,
              contentType: 'image/jpeg',
            ).timeout(const Duration(seconds: 15));
          } catch (_) {}
        }
        specialties.add(TechnicianSpecialty(
          skillId: d.skillId,
          skillLabel: d.skillLabel,
          description: d.descCtrl.text.trim(),
          details: d.detCtrl.text.trim(),
          diplomaImageUrl: dipUrl,
          status: SpecialtyStatus.pending,
          submittedAt: Timestamp.now(),
        ));
      }

      await _fs.saveTechnicianProfile(TechnicianProfile(
        techId: user.uid,
        fullName: _nameCtrl.text.trim(),
        phone: user.phoneNumber ?? '',
        city: _city ?? '',
        skills: const [],
        specialties: specialties,
        bio: _bioCtrl.text.trim(),
        yearsExperience: _years,
        hasDiploma: specialties.any((s) => s.diplomaImageUrl != null),
        diplomaNote: '',
        profilePhotoUrl: photoUrl,
        location: _pos != null ? GeoPoint(_pos!.latitude, _pos!.longitude) : null,
        age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
        onboardingComplete: true,
      ));
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'فشل الإرسال. عاود حاول.'; });
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          // ── Hero Header ───────────────────────────────────────────────────────
          _HeroHeader(
            step: _step,
            total: _kTotal,
            title: _kStepTitles[_step],
            sub: _kStepSubs[_step],
            onBack: _step > 0 ? _back : null,
            onRoleSwitch: _changeRole,
          ),
          // ── Animated Page Body ────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _pageFade,
              child: SlideTransition(
                position: _pageSlide,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: KeyedSubtree(key: ValueKey(_step), child: _buildPage()),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPage() => switch (_step) {
    0 => _Step0(
        photoBytes: _photoBytes,
        nameCtrl: _nameCtrl,
        city: _city,
        onPhoto: _pickPhoto,
        onCity: (c) => setState(() { _city = c; }),
        onChange: () => setState(() {}),
        canProceed: _ok0,
        onNext: _next,
      ),
    1 => _Step1(
        ageCtrl: _ageCtrl,
        years: _years,
        onYears: (v) => setState(() => _years = v),
        onChange: () => setState(() {}),
        canProceed: _ok1,
        onNext: _next,
      ),
    2 => _Step2(
        bioCtrl: _bioCtrl,
        onChange: () => setState(() {}),
        canProceed: _ok2,
        onNext: _next,
      ),
    3 => _Step3(
        specs: _specs,
        picker: _picker,
        onAdd: () => setState(() { if (_specs.length < 3) _specs.add(_SpecDraft()); }),
        onRemove: (i) => setState(() => _specs.removeAt(i)),
        onChange: () => setState(() {}),
        canProceed: _ok3,
        onNext: _next,
      ),
    4 => _Step4(
        pos: _pos,
        tried: _locTried,
        error: _error,
        onLocate: _locate,
        canProceed: _ok4,
        onNext: _next,
      ),
    _ => _Step5(
        name: _nameCtrl.text.trim(),
        city: _city ?? '—',
        age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
        years: _years,
        specs: _specs,
        hasLoc: _pos != null,
        busy: _busy,
        error: _error,
        onSubmit: _submit,
      ),
  };
}

// ════════════════════════════════════════════════════════════════════════════════
// HERO HEADER — dark green with wave + step dots
// ════════════════════════════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.sub,
    required this.onRoleSwitch,
    this.onBack,
  });

  final int step, total;
  final String title, sub;
  final VoidCallback? onBack;
  final VoidCallback onRoleSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kGreen,
      child: Column(children: [
        // top row
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 14, 0),
          child: Row(children: [
            SizedBox(
              width: 44,
              child: onBack != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
                      onPressed: onBack,
                    )
                  : null,
            ),
            // step dots
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final bool done   = i < step;
                  final bool active = i == step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 24 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: done
                          ? Colors.white
                          : active
                              ? _kGold
                              : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // role switch pill
            GestureDetector(
              onTap: onRoleSwitch,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.swap_horiz_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text('بدّل الدور',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ]),
              ),
            ),
          ]),
        ),
        // title block
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(step),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخطوة ${step + 1} من $total',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // wave
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(height: 24, color: _kBg),
        ),
      ]),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.75, size.height, size.width, size.height * 0.35);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

// ════════════════════════════════════════════════════════════════════════════════
// SHARED SHELL — scrollable body + pinned CTA
// ════════════════════════════════════════════════════════════════════════════════
class _Shell extends StatelessWidget {
  const _Shell({
    required this.child,
    required this.canProceed,
    required this.onNext,
    this.ctaLabel = 'التالي',
    this.ctaIcon = Icons.arrow_forward_rounded,
    this.loading = false,
  });

  final Widget child;
  final bool canProceed;
  final VoidCallback onNext;
  final String ctaLabel;
  final IconData ctaIcon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: child,
        ),
      ),
      // pinned CTA
      Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        decoration: BoxDecoration(
          color: _kBg,
          border: Border(top: BorderSide(color: _kBorder.withOpacity(0.6))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: canProceed ? _kGreen : _kBorder,
              foregroundColor: canProceed ? Colors.white : const Color(0xFF94A3B8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (canProceed && !loading) ? onNext : null,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      ctaLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (canProceed) ...[
                      const SizedBox(width: 6),
                      Icon(ctaIcon, size: 18),
                    ],
                  ]),
          ),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 0 — Identity (photo, name, city)
// ════════════════════════════════════════════════════════════════════════════════
class _Step0 extends StatefulWidget {
  const _Step0({
    required this.photoBytes,
    required this.nameCtrl,
    required this.city,
    required this.onPhoto,
    required this.onCity,
    required this.onChange,
    required this.canProceed,
    required this.onNext,
  });

  final Uint8List? photoBytes;
  final TextEditingController nameCtrl;
  final String? city;
  final VoidCallback onPhoto, onNext, onChange;
  final ValueChanged<String> onCity;
  final bool canProceed;

  @override
  State<_Step0> createState() => _Step0State();
}

class _Step0State extends State<_Step0> {
  @override
  Widget build(BuildContext context) {
    return _Shell(
      canProceed: widget.canProceed,
      onNext: widget.onNext,
      child: Column(children: [
        const SizedBox(height: 8),
        // avatar
        Center(
          child: GestureDetector(
            onTap: widget.onPhoto,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.photoBytes != null),
              tween: Tween(begin: 0.88, end: 1.0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGreenL,
                    border: Border.all(
                      color: widget.photoBytes != null ? _kGreen : _kBorder,
                      width: widget.photoBytes != null ? 2.5 : 1.5,
                      style: widget.photoBytes == null
                          ? BorderStyle.solid
                          : BorderStyle.solid,
                    ),
                    image: widget.photoBytes != null
                        ? DecorationImage(
                            image: MemoryImage(widget.photoBytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.photoBytes == null
                      ? const Icon(Icons.person_rounded,
                          size: 42, color: Color(0xFF94A3B8))
                      : null,
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBg, width: 2.2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 13, color: Colors.white),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('الصورة (اختيارية)',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
        ),
        const SizedBox(height: 22),
        // name
        _FieldLabel('الاسم الكامل', required: true),
        const SizedBox(height: 6),
        _ModernField(
          ctrl: widget.nameCtrl,
          hint: 'مثال: يوسف العلامي',
          icon: Icons.badge_outlined,
          valid: widget.nameCtrl.text.trim().isNotEmpty,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) { setState(() {}); widget.onChange(); },
        ),
        const SizedBox(height: 16),
        // city
        _FieldLabel('المدينة', required: true),
        const SizedBox(height: 6),
        _CityPicker(
          current: widget.city,
          onPick: widget.onCity,
        ),
        const SizedBox(height: 16),
        _InfoNote('الصورة اختيارية — الاسم والمدينة واجبيين للمتابعة'),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 1 — Age & Experience
// ════════════════════════════════════════════════════════════════════════════════
class _Step1 extends StatefulWidget {
  const _Step1({
    required this.ageCtrl,
    required this.years,
    required this.onYears,
    required this.onChange,
    required this.canProceed,
    required this.onNext,
  });

  final TextEditingController ageCtrl;
  final int years;
  final ValueChanged<int> onYears;
  final VoidCallback onChange, onNext;
  final bool canProceed;

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  @override
  Widget build(BuildContext context) {
    final a = int.tryParse(widget.ageCtrl.text.trim());
    final ageErr = widget.ageCtrl.text.isNotEmpty &&
        (a == null || a < 18 || a > 80);

    return _Shell(
      canProceed: widget.canProceed,
      onNext: widget.onNext,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _InfoNote('خاص يكون عندك 18 عام على الأقل'),
        const SizedBox(height: 14),
        _FieldLabel('شحال عمرك؟', required: true),
        const SizedBox(height: 6),
        _ModernField(
          ctrl: widget.ageCtrl,
          hint: 'مثال: 32',
          icon: Icons.cake_outlined,
          valid: !ageErr && widget.ageCtrl.text.isNotEmpty,
          keyboardType: TextInputType.number,
          errorText: ageErr ? 'العمر يكون بين 18 و80 سنة' : null,
          onChanged: (_) { setState(() {}); widget.onChange(); },
        ),
        const SizedBox(height: 24),
        _FieldLabel('سنين الخبرة العامة', required: false),
        const SizedBox(height: 10),
        // big slider card
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: Column(children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: widget.years),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$v',
                    style: const TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      color: _kGreen,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سنة',
                          style: TextStyle(
                              fontSize: 18,
                              color: _kMuted,
                              fontWeight: FontWeight.w600)),
                      Text('خبرة',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _kGreen,
                inactiveTrackColor: _kBorder,
                thumbColor: _kGreen,
                overlayColor: _kGreen.withOpacity(0.10),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                value: widget.years.toDouble(),
                min: 0,
                max: 40,
                divisions: 40,
                onChanged: (v) => widget.onYears(v.round()),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('0', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              Text('40 سنة',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 2 — Bio
// ════════════════════════════════════════════════════════════════════════════════
class _Step2 extends StatelessWidget {
  const _Step2({
    required this.bioCtrl,
    required this.onChange,
    required this.canProceed,
    required this.onNext,
  });

  final TextEditingController bioCtrl;
  final VoidCallback onChange, onNext;
  final bool canProceed;

  @override
  Widget build(BuildContext context) {
    final len = bioCtrl.text.trim().length;
    return _Shell(
      canProceed: canProceed,
      onNext: onNext,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _InfoNote('أقل من 20 حرف ما كتفيداش. كتب بالدارجة'),
        const SizedBox(height: 14),
        _FieldLabel('عرّف بنفسك للعملاء', required: true),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: len >= 20 ? _kGreen : _kBorder,
                width: len >= 20 ? 1.5 : 1.0),
          ),
          child: TextField(
            controller: bioCtrl,
            maxLines: 7,
            textDirection: TextDirection.rtl,
            onChanged: (_) => onChange(),
            style: const TextStyle(
              fontSize: 14.5,
              color: _kInk,
              height: 1.6,
            ),
            decoration: const InputDecoration(
              hintText:
                  'مثال: أنا سبّاك بعشر سنين خبرة فالدار البيضاء. متخصص فالشوفاج الشمسي. متاح 7 أيام...',
              hintStyle: TextStyle(
                  fontSize: 13.5, color: Color(0xFFCBD5E1), height: 1.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            len < 20 ? 'بقى ${20 - len} حرف' : 'مزيان ✓',
            style: TextStyle(
              fontSize: 12,
              color: len >= 20 ? _kGreen : _kMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('$len / 500',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ]),
        const SizedBox(height: 16),
        // amber tip
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _kAmberBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAmber.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: _kAmber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'قول واش كتدير، فين كتخدم، وشنو اللي كيميّزك على حساب الآخرين.',
                  style: TextStyle(
                      fontSize: 12.5, color: _kAmber, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 3 — Specialties
// ════════════════════════════════════════════════════════════════════════════════
class _Step3 extends StatefulWidget {
  const _Step3({
    required this.specs,
    required this.picker,
    required this.onAdd,
    required this.onRemove,
    required this.onChange,
    required this.canProceed,
    required this.onNext,
  });

  final List<_SpecDraft> specs;
  final ImagePicker picker;
  final VoidCallback onAdd, onChange, onNext;
  final ValueChanged<int> onRemove;
  final bool canProceed;

  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
  @override
  Widget build(BuildContext context) {
    final canAdd = widget.specs.length < 3;

    return _Shell(
      canProceed: widget.canProceed,
      onNext: widget.onNext,
      child: Column(children: [
        const SizedBox(height: 8),
        _InfoNote('واحدة على الأقل واجبة — 3 تخصصات كحد أقصى'),
        const SizedBox(height: 12),
        ...widget.specs.asMap().entries.map(
          (e) => _SpecCard(
            index: e.key,
            draft: e.value,
            picker: widget.picker,
            onRemove: () { widget.onRemove(e.key); },
            onChange: widget.onChange,
          ),
        ),
        if (canAdd) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () { widget.onAdd(); widget.onChange(); },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _kGreenL,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kGreen.withOpacity(0.35),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      color: _kGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.add_rounded,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.specs.isEmpty
                      ? '+ زيد أول تخصص'
                      : '+ زيد تخصص آخر  (${widget.specs.length}/3)',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _kGreen,
                  ),
                ),
              ]),
            ),
          ),
        ],
        if (!canAdd) ...[
          const SizedBox(height: 8),
          _InfoNote('وصلت للحد الأقصى — 3 تخصصات ✓'),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _SpecCard extends StatefulWidget {
  const _SpecCard({
    required this.index,
    required this.draft,
    required this.picker,
    required this.onRemove,
    required this.onChange,
  });

  final int index;
  final _SpecDraft draft;
  final ImagePicker picker;
  final VoidCallback onRemove, onChange;

  @override
  State<_SpecCard> createState() => _SpecCardState();
}

class _SpecCardState extends State<_SpecCard> {
  bool _expanded = true;

  Future<void> _pickSkill() async {
    final result = await showModalBottomSheet<TechnicianSkill>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('اختار التخصص',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _kInk)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: TechnicianSkill.all
                  .map((sk) => ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: _kGreenL,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(sk.icon, size: 20, color: _kGreen),
                        ),
                        title: Text(sk.label,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kInk)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        onTap: () => Navigator.pop(ctx, sk),
                      ))
                  .toList(),
            ),
          ),
        ]),
      ),
    );

    if (result != null) {
      setState(() {
        widget.draft.skillId    = result.id;
        widget.draft.skillLabel = result.label;
        widget.draft.skillIcon  = result.icon;
      });
      widget.onChange();
    }
  }

  Future<void> _pickDiploma() async {
    final f = await widget.picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() { widget.draft.dipFile = f; widget.draft.dipBytes = b; });
    widget.onChange();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: d.isComplete ? _kGreen : _kBorder,
          width: d.isComplete ? 1.5 : 1.0,
        ),
      ),
      child: Column(children: [
        // card header — tap to expand/collapse
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: d.isComplete ? _kGreenL : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  d.skillIcon ?? Icons.construction_outlined,
                  size: 19,
                  color: d.isComplete ? _kGreen : _kMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  d.skillLabel.isEmpty
                      ? 'التخصص ${widget.index + 1}'
                      : d.skillLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kInk),
                ),
                Text(
                  d.isComplete ? '✓ مكمّل' : 'ناقص — عمّر كل الخانات',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: d.isComplete ? _kGreen : _kDanger,
                  ),
                ),
              ])),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: _kDanger),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 200),
                child:
                    const Icon(Icons.expand_more_rounded, color: _kMuted, size: 22),
              ),
            ]),
          ),
        ),
        // expandable content
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(children: [
            Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const _FLbl('نوع التخصص *'),
                const SizedBox(height: 7),
                InkWell(
                  onTap: _pickSkill,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: d.skillId.isNotEmpty ? _kGreen : _kBorder),
                    ),
                    child: Row(children: [
                      Icon(d.skillIcon ?? Icons.handyman_outlined,
                          size: 18,
                          color: d.skillId.isNotEmpty ? _kGreen : _kMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          d.skillLabel.isEmpty ? 'اختار التخصص' : d.skillLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: d.skillLabel.isEmpty ? _kMuted : _kInk,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: _kMuted, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                const _FLbl('وصف الخبرة *'),
                const SizedBox(height: 7),
                _TextArea(
                  ctrl: d.descCtrl,
                  hint: 'مثال: سبّاك بثمانية سنين خبرة، متخصص فالشوفاج الشمسي...',
                  onChanged: (_) { setState(() {}); widget.onChange(); },
                ),
                const SizedBox(height: 12),
                const _FLbl('تفاصيل إضافية * (شهادات، معدات...)'),
                const SizedBox(height: 7),
                _TextArea(
                  ctrl: d.detCtrl,
                  hint: 'مثال: مشهود بيه من OFPPT 2018، معدات Roca...',
                  onChanged: (_) { setState(() {}); widget.onChange(); },
                ),
                const SizedBox(height: 14),
                // diploma
                Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                    Text('الشهادة (اختيارية)',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _kInk)),
                    Text('قادر تزيدها من بعد',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8))),
                  ])),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _pickDiploma,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 68,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: d.dipBytes != null ? _kGreen : _kBorder,
                          width: d.dipBytes != null ? 1.5 : 1.0,
                        ),
                      ),
                      child: d.dipBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.memory(d.dipBytes!, fit: BoxFit.cover),
                            )
                          : const Icon(Icons.upload_file_outlined,
                              color: _kMuted, size: 22),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 4 — Location
// ════════════════════════════════════════════════════════════════════════════════
class _Step4 extends StatelessWidget {
  const _Step4({
    required this.pos,
    required this.tried,
    required this.error,
    required this.onLocate,
    required this.canProceed,
    required this.onNext,
  });

  final Position? pos;
  final bool tried, canProceed;
  final String? error;
  final VoidCallback onLocate, onNext;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      canProceed: canProceed,
      onNext: onNext,
      child: Column(children: [
        const SizedBox(height: 8),
        _InfoNote('كنحتاجو الموقع باش نجيبوليك الطلبات القريبة منك'),
        const SizedBox(height: 28),
        Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(pos != null),
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pos != null ? _kGreenL : const Color(0xFFF8FAFC),
                border: Border.all(
                  color: pos != null ? _kGreen : _kBorder,
                  width: pos != null ? 2.5 : 1.5,
                ),
              ),
              child: Icon(
                pos != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.location_on_outlined,
                size: 52,
                color: pos != null ? _kGreen : _kMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            key: ValueKey(pos != null),
            pos != null ? 'الموقع تحدد ✓' : 'ما تحددش بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: pos != null ? _kGreen : _kInk,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, color: _kDanger, height: 1.4)),
        ],
        const SizedBox(height: 22),
        if (pos == null)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onLocate,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGreen,
                side: BorderSide(color: _kGreen.withOpacity(0.5), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                tried ? 'عاود حاول' : 'حدد بلاصتي',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _kBorder),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: _kMuted),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'الموقع كيتخدم فقط باش تتقرب من الطلبات. ما غادي نشاركوه مع حتى شكون.',
                  style: TextStyle(fontSize: 12, color: _kMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// STEP 5 — Review & Submit
// ════════════════════════════════════════════════════════════════════════════════
class _Step5 extends StatelessWidget {
  const _Step5({
    required this.name,
    required this.city,
    required this.age,
    required this.years,
    required this.specs,
    required this.hasLoc,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final String name, city;
  final int age, years;
  final List<_SpecDraft> specs;
  final bool hasLoc, busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      canProceed: !busy,
      onNext: onSubmit,
      ctaLabel: busy ? 'جاري الإرسال...' : 'يالاه نبداو',
      ctaIcon: Icons.rocket_launch_rounded,
      loading: busy,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        // summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: Column(children: [
            _ReviewRow('👤', 'الاسم', name.isEmpty ? '—' : name),
            _ReviewRow('🏙️', 'المدينة', city),
            _ReviewRow('🎂', 'العمر', age > 0 ? '$age سنة' : '—'),
            _ReviewRow('⏱️', 'الخبرة', '$years سنة'),
            _ReviewRow('📍', 'الموقع', hasLoc ? 'محدد ✓' : 'ما محددش',
                valueColor: hasLoc ? _kGreen : null),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('التخصصات',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kInk)),
        const SizedBox(height: 8),
        ...specs.map(
          (d) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kGreenL,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(d.skillIcon ?? Icons.build_outlined,
                  size: 18, color: _kGreen),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(d.skillLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kInk)),
                const Text('فانتظار موافقة الإدارة',
                    style: TextStyle(fontSize: 11, color: _kMuted)),
              ])),
              if (d.dipBytes != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAmberBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kAmber.withOpacity(0.3)),
                  ),
                  child: const Text('شهادة ✓',
                      style: TextStyle(
                          fontSize: 10,
                          color: _kAmber,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kDangerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kDanger.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 16, color: _kDanger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error!,
                    style: const TextStyle(
                        fontSize: 12.5, color: _kDanger)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _kAmberBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAmber.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_outlined, size: 15, color: _kAmber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التخصصات غادي تبان للعملاء بعد ما يراجعهم الفريق ديالنا. العادة أقل من 24 ساعة.',
                  style: TextStyle(
                      fontSize: 12, color: _kAmber, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// MICRO-WIDGETS
// ════════════════════════════════════════════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.required});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
      if (required)
        const Text(' *',
            style: TextStyle(fontSize: 13, color: _kDanger, fontWeight: FontWeight.bold))
      else
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('اختياري',
              style: TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}

class _FLbl extends StatelessWidget {
  const _FLbl(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted));
}

class _ModernField extends StatelessWidget {
  const _ModernField({
    required this.ctrl,
    required this.hint,
    required this.icon,
    required this.valid,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool valid;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: errorText != null
                ? _kDanger
                : valid
                    ? _kGreen
                    : _kBorder,
            width: valid ? 1.5 : 1.0,
          ),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: _kInk),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, size: 20, color: valid ? _kGreen : _kMuted),
            suffixIcon: valid
                ? const Icon(Icons.check_circle_rounded,
                    size: 20, color: _kGreen)
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 5, right: 4),
          child: Text(errorText!,
              style: const TextStyle(
                  fontSize: 12, color: _kDanger, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({required this.ctrl, required this.hint, this.onChanged});
  final TextEditingController ctrl;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: TextField(
      controller: ctrl,
      maxLines: 3,
      textDirection: TextDirection.rtl,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13.5, color: _kInk, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: Color(0xFFCBD5E1)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(12),
      ),
    ),
  );
}

class _CityPicker extends StatelessWidget {
  const _CityPicker({required this.current, required this.onPick});
  final String? current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final c = await showCityPicker(context, current: current);
      if (c != null) onPick(c);
    },
    borderRadius: BorderRadius.circular(14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current != null ? _kGreen : _kBorder,
          width: current != null ? 1.5 : 1.0,
        ),
      ),
      child: Row(children: [
        Icon(Icons.location_on_outlined,
            size: 20, color: current != null ? _kGreen : _kMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            current ?? 'اختار المدينة...',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  current != null ? FontWeight.w700 : FontWeight.normal,
              color: current != null ? _kInk : const Color(0xFFCBD5E1),
            ),
          ),
        ),
        Icon(
          current != null
              ? Icons.check_circle_rounded
              : Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: current != null ? _kGreen : _kMuted,
        ),
      ]),
    ),
  );
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: _kGreenL,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kGreen.withOpacity(0.2)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline_rounded, size: 14, color: _kGreen),
      const SizedBox(width: 7),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: _kGreen, height: 1.4)),
      ),
    ]),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.emoji, this.label, this.value, {this.valueColor});
  final String emoji, label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Text('$emoji  $label',
          style: const TextStyle(
              fontSize: 13, color: _kMuted, fontWeight: FontWeight.w600)),
      const Spacer(),
      Text(value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? _kInk,
          )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════════
// ROLE SWITCH BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════════════════
class _RoleSwitchSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(10)),
        ),
        const SizedBox(height: 20),
        const Text('باغي تبدّل الدور؟',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: _kInk)),
        const SizedBox(height: 8),
        const Text(
          'المعلومات اللي دخلتي فهاد الصفحة غادي يتمسحو وغادي ترجع لاختيار الحساب.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: _kMuted, height: 1.4),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kInk,
                side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('إلغاء',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDanger,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('نعم، بدّل',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// DRAFT MODEL
// ════════════════════════════════════════════════════════════════════════════════
class _SpecDraft {
  String skillId    = '';
  String skillLabel = '';
  IconData? skillIcon;
  final descCtrl = TextEditingController();
  final detCtrl  = TextEditingController();
  XFile?     dipFile;
  Uint8List? dipBytes;

  bool get isComplete =>
      skillId.isNotEmpty &&
      descCtrl.text.trim().isNotEmpty &&
      detCtrl.text.trim().isNotEmpty;

  void dispose() {
    descCtrl.dispose();
    detCtrl.dispose();
  }
}