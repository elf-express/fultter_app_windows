import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_flutter_app/theme/app_theme.dart' as app_theme;
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'localization/app_localizations.dart';

void main() async {
  // 確保 Flutter 初始化完成
  WidgetsFlutterBinding.ensureInitialized();

  // 創建主題實例並載入設定
  final appTheme = app_theme.AppTheme();
  await appTheme.loadSettings();

  runApp(MyApp(appTheme: appTheme));
}

class MyApp extends StatelessWidget {
  final app_theme.AppTheme appTheme;
  const MyApp({super.key, required this.appTheme});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<app_theme.AppTheme>.value(
      value: appTheme,
      child: Consumer<app_theme.AppTheme>(
        builder: (context, appTheme, _) {
          // 使用 AppTheme 實例中的主題
          final lightTheme = appTheme.lightTheme;
          final darkTheme = appTheme.darkTheme;
          
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
            localeResolutionCallback: (locale, supportedLocales) {
              // 如果語言不支援，使用第一個支援的語言
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              return supportedLocales.first;
            },
            supportedLocales: const [
              Locale('en', ''), // English
              Locale('zh', 'TW'), // Traditional Chinese (Taiwan)
              Locale('zh', 'CN'), // Simplified Chinese (China)
              Locale('ko', ''), // Korean
              Locale('ja', ''), // Japanese
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