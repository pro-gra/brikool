import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Supported languages in the app.
enum AppLanguage { ar, fr }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.ar ? 'ar' : 'fr';

  TextDirection get direction =>
      this == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr;
}

/// Loads and exposes the Darija (ar) / French (fr) dictionaries defined
/// in assets/lang/*.json.
class AppLocalizations {
  AppLocalizations._(this._strings);

  /// Public empty factory — returns an instance whose t(key) falls
  /// back to the key itself. Used by LanguageCubit as a placeholder
  /// for the single frame before the real JSON finishes loading.
  factory AppLocalizations.empty() => AppLocalizations._({});

  final Map<String, String> _strings;

  static final Map<AppLanguage, Map<String, String>> _cache = {};

  static Future<AppLocalizations> load(AppLanguage language) async {
    if (!_cache.containsKey(language)) {
      final raw =
          await rootBundle.loadString('assets/lang/${language.code}.json');
      final Map<String, dynamic> decoded = json.decode(raw);
      _cache[language] = decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    return AppLocalizations._(_cache[language]!);
  }

  /// Translate a key. Falls back to the key itself if missing.
  String t(String key) => _strings[key] ?? key;
}

/// InheritedWidget provider so any widget in the tree can read the
/// current language, direction, and translation function.
class LocalizationScope extends InheritedWidget {
  const LocalizationScope({
    super.key,
    required this.language,
    required this.localizations,
    required this.onLanguageChanged,
    required super.child,
  });

  final AppLanguage language;
  final AppLocalizations localizations;
  final ValueChanged<AppLanguage> onLanguageChanged;

  static LocalizationScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LocalizationScope>();
    assert(scope != null, 'No LocalizationScope found in context');
    return scope!;
  }

  String t(String key) => localizations.t(key);

  @override
  bool updateShouldNotify(LocalizationScope oldWidget) =>
      oldWidget.language != language;
}