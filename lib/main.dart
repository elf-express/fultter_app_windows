import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_flutter_app/theme/app_theme.dart' as app_theme;
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'localization/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<app_theme.AppTheme>(
      create: (context) => app_theme.AppTheme(),
      child: Consumer<app_theme.AppTheme>(
        builder: (context, appTheme, _) {
          // Create theme with current accent color
          final lightTheme = app_theme.AppTheme.lightTheme.copyWith(
            brightness: Brightness.light,
            accentColor: appTheme.color,
          );
          
          final darkTheme = app_theme.AppTheme.darkTheme.copyWith(
            brightness: Brightness.dark,
            accentColor: appTheme.color,
          );
          
          return FluentApp(
            title: 'My Flutter App',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: appTheme.mode,
            locale: appTheme.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''), // English
              Locale('zh', 'TW'), // Traditional Chinese (Taiwan)
            ],
            // Apply text direction to the entire app
            builder: (context, child) {
              AppLocalizations.ensureInitialized(context);
              return Directionality(
                textDirection: appTheme.textDirection,
                child: child!,
              );
            },
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}