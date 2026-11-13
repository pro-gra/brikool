import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/brikool_locale.dart';
import 'phone_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrikoolLanguage>(
      valueListenable: BrikoolLocale.language,
      builder: (context, language, _) {
        final isFrench = language == BrikoolLanguage.fr;
        final isArabic = language == BrikoolLanguage.ar;
        final title = isFrench
            ? 'Les bons pros.\nAu bon moment.'
            : isArabic
                ? 'محترفون موثوقون،\nوقت ما تحتاجهم.'
                : 'تقنيين ثقة،\nوقت ما تحتاجهم.';
        final subtitle = isFrench
            ? 'Trouvez facilement des professionnels près de chez vous pour vos travaux et dépannages.'
            : isArabic
                ? 'اعثر بسهولة على محترفين قريبين منك لخدمات المنزل والإصلاح.'
                : 'لقا بسهولة تقنيين قريبين ليك لخدمات الدار والإصلاح.';
        final steps = isFrench
            ? ['Décrivez votre besoin', 'Choisissez un professionnel', 'Suivez votre intervention']
            : isArabic
                ? ['حدد الخدمة التي تحتاجها', 'اختر المحترف المناسب', 'تابع طلبك خطوة بخطوة']
                : ['قول لينا شنو خاصك', 'اختار التقني اللي مناسب ليك', 'تبع الطلب ديالك خطوة بخطوة'];

        return Directionality(
          textDirection: BrikoolLocale.direction,
          child: Scaffold(
            backgroundColor: const Color(0xFFF6F9F7),
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: -110,
                    right: -100,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -120,
                    left: -110,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.asset(
                                  'assets/images/brikol_app_icon_192.png',
                                  width: 42,
                                  height: 42,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('brikool',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                            ]),
                            const BrikoolLanguagePicker(compact: true),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(.18),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Image.asset('assets/images/brikol_app_icon_192.png', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 34,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                            color: Color(0xFF14231B),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.65, color: Color(0xFF68766E)),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE8EEE9)),
                          ),
                          child: Column(
                            children: List.generate(3, (i) => Padding(
                              padding: EdgeInsets.only(bottom: i == 2 ? 0 : 16),
                              child: Row(children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEAF5EE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text('${i + 1}', style: const TextStyle(
                                      color: AppColors.primary, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(steps[i],
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF26362D)))),
                                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                              ]),
                            )),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 58,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isFrench ? 'Commencer' : isArabic ? 'ابدأ الآن' : 'يلا نبداو',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward_rounded, size: 19),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isFrench ? 'Simple • Fiable • Près de chez vous' :
                          isArabic ? 'بسهولة • ثقة • قريب منك' : 'بسهولة • بالثقة • قريب ليك',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF849188), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
