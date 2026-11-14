import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/localization/brikool_locale.dart';
import '../../../company/presentation/screens/company_registration_screen.dart';
import '../../../client/presentation/screens/client_onboarding_screen.dart';
import '../../../technician/presentation/screens/technician_onboarding_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final _fs = FirestoreService();
  bool _loading = false;
  String _choice = 'client';

  String tr(String fr, String ar, String darija) =>
      BrikoolLocale.text(fr, ar: ar, darija: darija);

  Future<void> _confirm() async {
    if (_choice == 'company') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const CompanyRegistrationScreen(),
      ));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _loading) return;
    setState(() => _loading = true);
    try {
      await _fs.setUserRole(user.uid, _choice);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => _choice == 'client'
            ? const ClientOnboardingScreen()
            : const TechnicianOnboardingScreen(),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Impossible d’enregistrer votre choix. Réessayez.',
              'تعذر حفظ اختيارك. حاول مرة أخرى.', 'ما قدرناش نحفظو الاختيار ديالك. عاود حاول.')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrikoolLanguage>(
      valueListenable: BrikoolLocale.language,
      builder: (context, language, _) {
        final fr = language == BrikoolLanguage.fr;
        final ar = language == BrikoolLanguage.ar;
        final title = fr ? 'Comment souhaitez-vous utiliser Brikool ?'
            : ar ? 'كيف تريد استخدام بريكول؟' : 'كيفاش بغيتي تستعمل بريكول؟';
        final subtitle = fr ? 'Choisissez votre parcours. Vous pourrez compléter votre profil ensuite.'
            : ar ? 'اختر نوع حسابك. يمكنك إكمال ملفك الشخصي لاحقاً.'
            : 'اختار نوع الحساب ديالك، وكمل المعلومات من بعد.';
        final choices = <(String,String,String,String,IconData)>[
          ('client',
            fr ? 'Trouver un professionnel' : ar ? 'أبحث عن محترف' : 'كنقلب على تقني',
            fr ? 'Pour vos réparations et services du quotidien' : ar ? 'لإصلاحاتك وخدماتك اليومية' : 'لإصلاحات وخدمات الدار',
            fr ? 'CLIENT' : ar ? 'زبون' : 'زبون',
            Icons.home_repair_service_rounded),
          ('technician',
            fr ? 'Proposer mes services' : ar ? 'أقدم خدماتي' : 'باغي نخدم كتقني',
            fr ? 'Recevez des demandes et développez votre activité' : ar ? 'استقبل الطلبات وطوّر عملك' : 'استقبل الطلبات وكبر الخدمة ديالك',
            fr ? 'PRO' : ar ? 'مهني' : 'مهني',
            Icons.handyman_rounded),
          ('company',
            fr ? 'Inscrire mon entreprise' : ar ? 'تسجيل شركتي' : 'نسجل الشركة ديالي',
            fr ? 'Gérez vos projets et demandes de devis' : ar ? 'أدر مشاريعك وطلبات عروض الأسعار' : 'سير المشاريع وطلبات الأثمنة',
            fr ? 'ENTREPRISE' : ar ? 'شركة' : 'شركة',
            Icons.domain_rounded),
        ];
        return Directionality(
          textDirection: BrikoolLocale.direction,
          child: Scaffold(
            backgroundColor: const Color(0xFFF6F9F7),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(11),
                          child: Image.asset('assets/images/brikol_app_icon_192.png', width: 38, height: 38)),
                        const SizedBox(width: 9),
                        const Text('brikool', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      ]),
                      const BrikoolLanguagePicker(compact: true),
                    ]),
                    const SizedBox(height: 38),
                    Text(title, textAlign: TextAlign.start,
                      style: const TextStyle(fontSize: 27, height: 1.18, fontWeight: FontWeight.w900, color: Color(0xFF15251C))),
                    const SizedBox(height: 10),
                    Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF738078))),
                    const SizedBox(height: 28),
                    Expanded(child: ListView.separated(
                      itemCount: choices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 13),
                      itemBuilder: (context, index) {
                        final item = choices[index];
                        final selected = _choice == item.$1;
                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _choice = item.$1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: selected ? const Color(0xFF0F8A54) : const Color(0xFFE5ECE7), width: selected ? 2 : 1),
                              boxShadow: selected ? [BoxShadow(color: const Color(0xFF0F8A54).withOpacity(.09), blurRadius: 22, offset: const Offset(0, 8))] : [],
                            ),
                            child: Row(children: [
                              Container(width: 52, height: 52,
                                decoration: BoxDecoration(color: selected ? const Color(0xFFEAF5EE) : const Color(0xFFF3F6F4), borderRadius: BorderRadius.circular(16)),
                                child: Icon(item.$5, color: const Color(0xFF0F8A54), size: 25)),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.$2, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF1D2A22))),
                                const SizedBox(height: 5),
                                Text(item.$3, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF78847D))),
                              ])),
                              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                color: selected ? const Color(0xFF0F8A54) : const Color(0xFFD3DDD6), size: 23),
                            ]),
                          ),
                        );
                      },
                    )),
                    SizedBox(height: 58, child: FilledButton(
                      onPressed: _loading ? null : _confirm,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F8A54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(tr('Continuer', 'متابعة', 'كمل'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    )),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
