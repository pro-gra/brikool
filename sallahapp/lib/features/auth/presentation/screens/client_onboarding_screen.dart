import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../models/moroccan_cities.dart';

// ── COLOR IDENTITY (Inspired directly by your posters & logo) ────────────────
const _kDarkCanvas    = Color(0xFF071E18);
const _kEmeraldBrand  = Color(0xFF0D6E54);
const _kMintActive    = Color(0xFF10B981);
const _kCardSurface   = Color(0xFFFFFFFF);
const _kBorderLight   = Color(0xFFE2E8F0);
const _kInkText       = Color(0xFF0F172A);
const _kSlateMuted    = Color(0xFF64748B);
const _kAlertDanger   = Color(0xFFEF4444);

class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
  final _fs = FirestoreService();
  final _storage = StorageService();
  final _picker = ImagePicker();
  final _nameCtrl = TextEditingController();

  // Instant Setup State
  String? _city;
  final Set<String> _selectedNeeds = {'الدار'}; // Default selected
  Uint8List? _photoBytes;
  XFile? _photoFile;
  bool _saving = false;
  String? _error;

  static const _popularCities = ['الدار البيضاء', 'الرباط', 'مراكش', 'طنجة', 'فاس', 'أكادير'];

  static const _serviceNeeds = [
    ('الدار', Icons.home_repair_service_rounded, 'سباكة، كهرباء، صباغة'),
    ('الطوموبيل', Icons.directions_car_rounded, 'ميكانيك، بنك، ديباناج'),
    ('المطبخ', Icons.kitchen_rounded, 'ثلاجة، لاف-فيج، فران'),
    ('الكليماتيزور', Icons.ac_unit_rounded, 'تركيب، صيانة، تنظيف'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canActivate => _nameCtrl.text.trim().length >= 2 && _city != null;

  Future<void> _pickPhoto() async {
    HapticFeedback.selectionClick();
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoFile = file;
      _photoBytes = bytes;
    });
  }

  Future<void> _changeRole() async {
    HapticFeedback.lightImpact();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorderLight,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'باغي ترجع لاختيار الحساب؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInkText),
            ),
            const SizedBox(height: 8),
            const Text(
              'تقدر تسجل كتقني دابا وتستقبل الطلبات من الزبناء.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kSlateMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: _kBorderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إلغاء', style: TextStyle(color: _kInkText, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAlertDanger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('نعم، تبديل لتقني', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': FieldValue.delete()});
  }

  Future<void> _activateRadar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'انتهت الجلسة. عاود سجّل الدخول.');
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? photoUrl;
      if (_photoFile != null && _photoBytes != null) {
        try {
          photoUrl = await _storage.upload(
            path: 'users/${user.uid}/profile.jpg',
            localPathOrIgnoredOnWeb: _photoFile!.path,
            bytes: _photoBytes!,
            contentType: 'image/jpeg',
          ).timeout(const Duration(seconds: 15));
        } catch (_) {}
      }

      await _fs.updateUserProfile(
        user.uid,
        fullName: _nameCtrl.text.trim(),
        photoUrl: photoUrl,
        city: _city,
        referralSource: _selectedNeeds.join(', '),
        clientOnboardingComplete: true,
      );

      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر الاتصال بالخادم. تأكد من الإنترنت.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── TOP RADAR HEADER ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/brikol_app_icon_192.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'brikool',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _saving ? null : _changeRole,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'نتا تقني؟',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── LIVE TECH RADAR PULSE CARD ──────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kMintActive.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.radar_rounded, color: _kMintActive, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _kMintActive,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'رادار الحِرَفيين متصل ومتاح',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _city == null
                              ? 'حدد مدينتك لاكتشاف أقرب تقني متوفر'
                              : 'كاينين حِرَفيين معتمدين فـ $_city جاهزين للتدخل فـ 8 دقيق',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── MAIN ACTIVATION BOTTOM SHEET ─────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Services User Needs
                      const Text(
                        '1. فين كتحتاج الحِرَفي أكثر؟',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kInkText),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اختار المجالات باش التطبيق يرتب ليك التقنيين المناسبين',
                        style: TextStyle(fontSize: 12, color: _kSlateMuted),
                      ),
                      const SizedBox(height: 14),
                      _buildNeedsGrid(),
                      const SizedBox(height: 26),

                      // Section 2: Quick City Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '2. أين مكان إقامتك؟',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kInkText),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final c = await showCityPicker(context, current: _city);
                              if (c != null && mounted) {
                                HapticFeedback.selectionClick();
                                setState(() => _city = c);
                              }
                            },
                            child: const Text(
                              'كل المدن ▾',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kEmeraldBrand),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildCityChips(),
                      const SizedBox(height: 26),

                      // Section 3: Identity & Photo
                      const Text(
                        '3. الاسم وصورة الحساب',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kInkText),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Photo Bubble
                          GestureDetector(
                            onTap: _pickPhoto,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF1F5F9),
                                    border: Border.all(
                                      color: _photoBytes != null ? _kMintActive : _kBorderLight,
                                      width: 2,
                                    ),
                                    image: _photoBytes != null
                                        ? DecorationImage(image: MemoryImage(_photoBytes!), fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: _photoBytes == null
                                      ? const Icon(Icons.add_a_photo_outlined, size: 22, color: _kSlateMuted)
                                      : null,
                                ),
                                if (_photoBytes != null)
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(color: _kMintActive, shape: BoxShape.circle),
                                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name Input
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _nameCtrl.text.trim().length >= 2 ? _kEmeraldBrand : _kBorderLight,
                                  width: 1.4,
                                ),
                              ),
                              child: TextField(
                                controller: _nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInkText),
                                decoration: const InputDecoration(
                                  hintText: 'الاسم والنسب الكامل',
                                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: _kAlertDanger, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 30),

                      // ── MAIN ACTIVATE CTA ─────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _canActivate ? _kDarkCanvas : const Color(0xFFCBD5E1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: _canActivate ? 4 : 0,
                          ),
                          onPressed: (_canActivate && !_saving) ? _activateRadar : null,
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _canActivate ? 'تفعيل الحساب والبدء دابا' : 'حدد المدينة والاسم للمتابعة',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                    if (_canActivate) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'حسابك مجاني ومحمي بالكامل 🔒',
                          style: TextStyle(fontSize: 11.5, color: _kSlateMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── GRID OF SELECTABLE PROBLEM DOMAINS ────────────────────────────────────
  Widget _buildNeedsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: _serviceNeeds.map((item) {
        final (title, icon, sub) = item;
        final selected = _selectedNeeds.contains(title);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (selected) {
                if (_selectedNeeds.length > 1) _selectedNeeds.remove(title);
              } else {
                _selectedNeeds.add(title);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kEmeraldBrand.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _kEmeraldBrand : _kBorderLight,
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: selected ? _kEmeraldBrand : _kSlateMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: selected ? _kDarkCanvas : _kInkText,
                        ),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9.5, color: _kSlateMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── QUICK ONE-TAP CITY PILLS ───────────────────────────────────────────────
  Widget _buildCityChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _popularCities.map((cityName) {
        final isSelected = _city == cityName;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _city = cityName);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? _kDarkCanvas : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _kDarkCanvas : _kBorderLight,
                width: 1.2,
              ),
            ),
            child: Text(
              cityName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : _kInkText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}