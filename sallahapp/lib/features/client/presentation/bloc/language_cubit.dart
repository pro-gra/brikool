import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/app_localizations.dart';

// AppLanguage enum is defined in app_localizations.dart — don't redefine it here.

class LanguageState {
  const LanguageState(this.language, this.localizations);
  final AppLanguage language;
  final AppLocalizations localizations;

  String t(String key) => localizations.t(key);
}

class LanguageCubit extends Cubit<LanguageState> {
  /// Defaults to Darija Arabic. The JSON loads asynchronously;
  /// until it's ready, t(key) falls back to the key itself (via AppLocalizations.empty()).
  LanguageCubit({AppLanguage initialLanguage = AppLanguage.ar})
      : super(LanguageState(initialLanguage, AppLocalizations.empty())) {
    _load(initialLanguage);
  }

  Future<void> _load(AppLanguage lang) async {
    final locs = await AppLocalizations.load(lang);
    emit(LanguageState(lang, locs));
  }

  Future<void> setLanguage(AppLanguage lang) async {
    // Emit immediately with empty so UI doesn't wait on the old language.
    emit(LanguageState(lang, AppLocalizations.empty()));
    final locs = await AppLocalizations.load(lang);
    emit(LanguageState(lang, locs));
  }

  Future<void> toggle() async {
    final next =
        state.language == AppLanguage.ar ? AppLanguage.fr : AppLanguage.ar;
    await setLanguage(next);
  }

  bool get isArabic => state.language == AppLanguage.ar;
}