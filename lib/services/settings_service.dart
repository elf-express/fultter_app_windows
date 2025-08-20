import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class SettingsService {
  // 語言設定
  static const String _localeLanguageKey = 'locale_language';
  static const String _localeCountryKey = 'locale_country';
  
  // 導航指示器
  static const String _navigationIndicatorKey = 'navigation_indicator';
  
  // 強調色
  static const String _accentColorKey = 'accent_color';
  
  // 文字方向
  static const String _textDirectionKey = 'text_direction';

  // 保存語言設定
  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeLanguageKey, locale.languageCode);
    if (locale.countryCode != null) {
      await prefs.setString(_localeCountryKey, locale.countryCode!);
    }
  }

  // 讀取保存的語言設定
  static Future<Locale?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeLanguageKey);
    if (languageCode == null) return null;

    final countryCode = prefs.getString(_localeCountryKey);
    return Locale(languageCode, countryCode);
  }
  
  // 保存導航指示器設定
  static Future<void> saveNavigationIndicator(NavigationIndicators indicator) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_navigationIndicatorKey, indicator.toString());
  }
  
  // 讀取導航指示器設定
  static Future<NavigationIndicators> getNavigationIndicator() async {
    final prefs = await SharedPreferences.getInstance();
    final indicatorString = prefs.getString(_navigationIndicatorKey);
    if (indicatorString == null) return NavigationIndicators.sticky;
    
    return NavigationIndicators.values.firstWhere(
      (e) => e.toString() == indicatorString,
      orElse: () => NavigationIndicators.sticky,
    );
  }
  
  // 保存強調色
  static Future<void> saveAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.value);
  }
  
  // 讀取強調色
  static Future<Color> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_accentColorKey);
    return colorValue != null ? Color(colorValue) : Colors.orange;
  }
  
  // 保存文字方向
  static Future<void> saveTextDirection(TextDirection direction) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_textDirectionKey, direction == TextDirection.rtl);
  }
  
  // 讀取文字方向
  static Future<TextDirection> getTextDirection() async {
    final prefs = await SharedPreferences.getInstance();
    final isRtl = prefs.getBool(_textDirectionKey) ?? false;
    return isRtl ? TextDirection.rtl : TextDirection.ltr;
  }
}