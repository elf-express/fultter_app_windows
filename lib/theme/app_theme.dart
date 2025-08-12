import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:system_theme/system_theme.dart';

enum NavigationIndicators { sticky, end }

class AppTheme extends ChangeNotifier {
  static final lightTheme = FluentThemeData(
    brightness: Brightness.light,
    accentColor: Colors.blue,
    // Add more theme configurations here
  );

  static final darkTheme = FluentThemeData(
    brightness: Brightness.dark,
    accentColor: Colors.blue,
    // Add more theme configurations here
  );

  AccentColor? _color;
  AccentColor get color => _color ?? systemAccentColor;
  set color(AccentColor color) {
    _color = color;
    notifyListeners();
  }

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  set mode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  // Always use compact display mode
  PaneDisplayMode get displayMode => PaneDisplayMode.compact;
  
  // Disable setting display mode since we want to keep it always compact
  set displayMode(PaneDisplayMode _) {
    // No-op to prevent changing the display mode
  }

  NavigationIndicators _indicator = NavigationIndicators.sticky;
  NavigationIndicators get indicator => _indicator;
  set indicator(NavigationIndicators indicator) {
    _indicator = indicator;
    notifyListeners();
  }

  WindowEffect _windowEffect = WindowEffect.disabled;
  WindowEffect get windowEffect => _windowEffect;
  set windowEffect(WindowEffect windowEffect) {
    _windowEffect = windowEffect;
    notifyListeners();
  }

  void setEffect(WindowEffect effect, BuildContext context) {
    Window.setEffect(
      effect: effect,
      color: [WindowEffect.solid, WindowEffect.acrylic].contains(effect)
          ? FluentTheme.of(context).micaBackgroundColor.withValues(alpha: 0.05)
          : Colors.transparent,
      dark: FluentTheme.of(context).brightness.isDark,
    );
  }

  TextDirection _textDirection = TextDirection.ltr;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection direction) {
    _textDirection = direction;
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
