import 'package:flutter/material.dart';

enum BrikoolLanguage { fr, ar, darija }

class BrikoolLocale {
  BrikoolLocale._();
  static final ValueNotifier<BrikoolLanguage> language =
      ValueNotifier<BrikoolLanguage>(BrikoolLanguage.fr);

  static String text(
    String fr, {
    required String ar,
    required String darija,
  }) {
    switch (language.value) {
      case BrikoolLanguage.fr:
        return fr;
      case BrikoolLanguage.ar:
        return ar;
      case BrikoolLanguage.darija:
        return darija;
    }
  }

  static TextDirection get direction =>
      language.value == BrikoolLanguage.fr
          ? TextDirection.ltr
          : TextDirection.rtl;
}

class BrikoolLanguagePicker extends StatelessWidget {
  const BrikoolLanguagePicker({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrikoolLanguage>(
      valueListenable: BrikoolLocale.language,
      builder: (context, selected, _) {
        final options = <(BrikoolLanguage, String)>[
          (BrikoolLanguage.fr, 'FR'),
          (BrikoolLanguage.ar, 'عربي'),
          (BrikoolLanguage.darija, 'Darija'),
        ];
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE4EAE6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              final active = selected == option.$1;
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => BrikoolLocale.language.value = option.$1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 9 : 12,
                    vertical: compact ? 7 : 9,
                  ),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF0F8A54) : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF64748B),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
