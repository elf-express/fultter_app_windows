import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:system_theme/system_theme.dart';

import '../services/settings_service.dart';

enum NavigationIndicators { sticky, end }

class AppTheme extends ChangeNotifier {

  // 載入保存的設定
  Future<void> loadSettings() async {
    // 載入語言設定
    final savedLocale = await SettingsService.getLocale();
    if (savedLocale != null) {
      _locale = savedLocale;
    }
    
    // 載入導航指示器設定
    _indicator = await SettingsService.getNavigationIndicator();
    
    // 載入強調色
    final savedColor = await SettingsService.getAccentColor();
    _color = Colors.accentColors.firstWhere(
      (c) => c.normal == savedColor,
      orElse: () => Colors.orange,
    );
    
    // 載入文字方向
    _textDirection = await SettingsService.getTextDirection();
    
    notifyListeners();
  }

  static FluentThemeData _buildThemeData(Brightness brightness, AccentColor accentColor) {
    return FluentThemeData(
      brightness: brightness,
      accentColor: accentColor,
      navigationPaneTheme: NavigationPaneThemeData(
        highlightColor: accentColor,
      ),
      // Add more theme configurations here
    );
  }

  FluentThemeData get lightTheme => _buildThemeData(Brightness.light, _color ?? Colors.orange);
  FluentThemeData get darkTheme => _buildThemeData(Brightness.dark, _color ?? Colors.orange);

  AccentColor? _color;
  AccentColor get color => _color ?? Colors.orange;
  set color(AccentColor color) {
    if (_color == color) return;
    _color = color;
    SettingsService.saveAccentColor(color.normal);
    notifyListeners();
  }

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  set mode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  PaneDisplayMode _displayMode = PaneDisplayMode.compact;
  PaneDisplayMode get displayMode => _displayMode;
  set displayMode(PaneDisplayMode displayMode) {
    if (_displayMode == displayMode) return;
    _displayMode = displayMode;
    notifyListeners();
  }

  NavigationIndicators _indicator = NavigationIndicators.sticky;
  NavigationIndicators get indicator => _indicator;
  set indicator(NavigationIndicators indicator) {
    if (_indicator == indicator) return;
    _indicator = indicator;
    SettingsService.saveNavigationIndicator(indicator);
    notifyListeners();
  }

  TextDirection _textDirection = TextDirection.ltr;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection direction) {
    if (_textDirection == direction) return;
    _textDirection = direction;
    SettingsService.saveTextDirection(direction);
    notifyListeners();
  }

  Locale? _locale;
  Locale? get locale => _locale;
  set locale(Locale? locale) {
    _locale = locale;
    // Update text direction based on locale if needed
    if (locale != null) {
      _textDirection = _isRTL(locale.languageCode)
          ? TextDirection.rtl
          : TextDirection.ltr;
      SettingsService.saveLocale(locale); // 保存語言設定
    }
    notifyListeners();
  }

  bool _isRTL(String languageCode) {
    // Add RTL languages here if needed
    return false;
  }
}

AccentColor get systemAccentColor {
  if ((defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.android) &&
      !kIsWeb) {
    return AccentColor.swatch({
      'darkest': SystemTheme.accentColor.darkest,
      'darker': SystemTheme.accentColor.darker,
      'dark': SystemTheme.accentColor.dark,
      'normal': SystemTheme.accentColor.accent,
      'light': SystemTheme.accentColor.light,
      'lighter': SystemTheme.accentColor.lighter,
      'lightest': SystemTheme.accentColor.lightest,
    });
  }
  return Colors.blue;
}
