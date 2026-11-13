import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../company/presentation/screens/company_registration_screen.dart';
import '../../../client/presentation/screens/client_onboarding_screen.dart';
import '../../../technician/presentation/screens/technician_onboarding_screen.dart';

// ── Minimalist Brand Tokens ──────────────────────────────────────────────────
const _kBrandGreen = Color(0xFF0F8A54);
const _kBrandTeal  = Color(0xFF027A87);
const _kDarkInk    = Color(0xFF0F172A);
const _kMuted      = Color(0xFF64748B);
const _kBg         = Color(0xFFFAFBFC);
const _kBorder     = Color(0xFFE2E8F0);

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _fs = FirestoreService();
  bool _loading = false;
  bool _step2 = false;
  int _activeChoice = 0; // 0: Left, 1: Right

  Future<void> _handleConfirm() async {
    if (!_step2) {
      if (_activeChoice == 0) {
        setState(() {
          _step2 = true;
          _activeChoice = 0;
        });
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CompanyRegistrationScreen()),
        );
      }
      return;
    }

    final role = _activeChoice == 0 ? 'client' : 'technician';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      await _fs.setUserRole(user.uid, role);
    } catch (_) {}

    if (!mounted) return;

    if (role == 'client') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ClientOnboardingScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TechnicianOnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirstStep = !_step2;

    final leftTitle = isFirstStep ? 'شخص عادي' : 'كليان';
    final leftDesc = isFirstStep ? 'خدمات منزلية وسيارات' : 'كنقلب على تقني لحل المشكل';
    final leftIcon = isFirstStep ? Icons.person_rounded : Icons.search_rounded;

    final rightTitle = isFirstStep ? 'شركة / مقاول' : 'حِرَفي / تقني';
    final rightDesc = isFirstStep ? 'مشاريع وصفقات كبرى' : 'باغي نخدم وندخل مدخول';
    final rightIcon = isFirstStep ? Icons.domain_rounded : Icons.handyman_rounded;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Navigation & Stepper ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step2)
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _kBorder),
                      ),
                      onPressed: () => setState(() => _step2 = false),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kDarkInk),
                    )
                  else
                    const SizedBox(width: 40),
                  // Progress Dots
                  Row(
                    children: [
                      _StepDot(isActive: true),
                      const SizedBox(width: 6),
                      _StepDot(isActive: _step2),
                    ],
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 36),

              // ── Headline ────────────────────────────────────────────────
              Center(
                child: Text(
                  _step2 ? 'شنو هو دورك؟' : 'مرحباً بك فـ brikool',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _kDarkInk,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _step2 ? 'حدد كيفاش بغيتي تستعمل التطبيق' : 'اختار نوع الحساب اللي يناسبك',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: _kMuted),
                ),
              ),
              const SizedBox(height: 40),

              // ── Dynamic 2-Panel Minimal Deck ────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _CleanRoleCard(
                        title: leftTitle,
                        subtitle: leftDesc,
                        icon: leftIcon,
                        isSelected: _activeChoice == 0,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeChoice = 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _CleanRoleCard(
                        title: rightTitle,
                        subtitle: rightDesc,
                        icon: rightIcon,
                        isSelected: _activeChoice == 1,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeChoice = 1);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Clean Floating Action Button ────────────────────────────
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kDarkInk,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _loading ? null : _handleConfirm,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _step2 ? 'تأكيد ودخول' : 'متابعة',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modern Clean Selection Card ──────────────────────────────────────────────
class _CleanRoleCard extends StatelessWidget {
  const _CleanRoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kBrandGreen : _kBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _kBrandGreen.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: isSelected ? 18 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _kBrandGreen : const Color(0xFFF1F5F9),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : _kMuted,
                size: 26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isSelected ? _kDarkInk : _kDarkInk.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                color: _kMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _kBrandGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _kBrandGreen : _kBorder,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Stepper Indicator ────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  const _StepDot({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 24 : 8,
      height: 6,
      decoration: BoxDecoration(
        color: isActive ? _kBrandGreen : _kBorder,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}