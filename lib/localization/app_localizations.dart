import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_localizations_en.dart';
import 'app_localizations_zh_tw.dart';
import 'app_localizations_zh_cn.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ja.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Helper method to keep the code in the widgets concise
  static AppLocalizations? get instance => _instance;
  static AppLocalizations? _instance;
  static void ensureInitialized(BuildContext context) {
    _instance = AppLocalizations.of(context);
  }

  // Localized strings
  Map<String, String> _localizedStrings = {};

  Future<bool> load() async {
    _instance = this;
    
    switch (locale.languageCode) {
      case 'zh':
        if (locale.countryCode == 'TW') {
          _localizedStrings = zhTW;
        } else if (locale.countryCode == 'CN') {
          _localizedStrings = zhCN;
        } else {
          _localizedStrings = en;
        }
        break;
      case 'ko':
        _localizedStrings = ko;
        break;
      case 'ja':
        _localizedStrings = ja;
        break;
      default:
        _localizedStrings = en;
    }
    return true;
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh', 'ko', 'ja'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Helper class to access translations with shorter syntax
extension LocalizationExtension on BuildContext {
  String tr(String key) {
    return AppLocalizations.of(this)?.translate(key) ?? key;
  }
}
