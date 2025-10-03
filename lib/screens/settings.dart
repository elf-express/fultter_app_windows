// ignore_for_file: constant_identifier_names

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../widgets/page.dart';
import '../localization/app_localizations.dart';


const List<String> accentColorNames = [
  'Yellow',
  'Orange',
  'Red',
  'Magenta',
  'Purple',
  'Blue',
  'Teal',
  'Green',
];

bool get kIsWindowEffectsSupported {
  return !kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
}

class Settings extends StatefulWidget {
  const Settings({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with PageMixin {
  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final appTheme = context.watch<AppTheme>();
    const spacer = SizedBox(height: 10.0);
    const biggerSpacer = SizedBox(height: 40.0);

    final currentLocale =
        appTheme.locale ?? Localizations.maybeLocaleOf(context);
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back, size: 20),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!(); // 交給 HomeScreen 切回上一個 pane
                  return;
                }
                // 後備機制：若未提供 onBack，嘗試 pop；不行就啥都不做
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                }
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
            ),
            const SizedBox(width: 8),
            Text(context.tr('settings')),
          ],
        ),
      ),
      children: [
        // Theme mode and Navigation Pane Display Mode settings are hidden as per requirements
        biggerSpacer,
        Text(
          context.tr('navigationIndicator'),
          style: FluentTheme.of(context).typography.subtitle,
        ),
        spacer,
        ...List.generate(NavigationIndicators.values.length, (index) {
          final mode = NavigationIndicators.values[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8.0),
            child: RadioButton(
              checked: appTheme.indicator == mode,
              onChanged: (value) {
                if (value) appTheme.indicator = mode;
              },
              content: Text(
                context.tr(mode.toString().replaceAll('NavigationIndicators.', '').toLowerCase()),
              ),
            ),
          );
        }),
        biggerSpacer,
        Text(
          context.tr('accentColor'),
          style: FluentTheme.of(context).typography.subtitle,
        ),
        spacer,
        Wrap(
          children: List.generate(Colors.accentColors.length, (index) {
            final color = Colors.accentColors[index];
            return Tooltip(
              message: accentColorNames[index],
              child: _buildColorBlock(appTheme, color),
            );
          }),
        ),
        biggerSpacer,
        Text(
          context.tr('textDirection'),
          style: FluentTheme.of(context).typography.subtitle,
        ),
        spacer,
        ...List.generate(TextDirection.values.length, (index) {
          final direction = TextDirection.values[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8.0),
            child: RadioButton(
              checked: appTheme.textDirection == direction,
              onChanged: (value) {
                if (value) {
                  appTheme.textDirection = direction;
                }
              },
              content: Text(
                '$direction'
                    .replaceAll('TextDirection.', '')
                    .replaceAll('rtl', context.tr('rightToLeft'))
                    .replaceAll('ltr', context.tr('leftToRight')),
              ),
            ),
          );
        }).reversed,
        biggerSpacer,
        Text(context.tr('locale'), style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Wrap(
          spacing: 15.0,
          runSpacing: 10.0,
          children: [
            // English
            RadioButton(
              checked: currentLocale?.languageCode == 'en',
              onChanged: (value) {
                if (value) {
                  appTheme.locale = const Locale('en');
                }
              },
              content: const Text('English'),
            ),
            // Traditional Chinese
            RadioButton(
              checked: currentLocale?.languageCode == 'zh' && currentLocale?.countryCode == 'TW',
              onChanged: (value) {
                if (value) {
                  appTheme.locale = const Locale('zh', 'TW');
                }
              },
              content: const Text('繁體中文'),
            ),
            // Simplified Chinese
            RadioButton(
              checked: currentLocale?.languageCode == 'zh' && currentLocale?.countryCode == 'CN',
              onChanged: (value) {
                if (value) {
                  appTheme.locale = const Locale('zh', 'CN');
                }
              },
              content: const Text('简体中文'),
            ),
            // Korean
            RadioButton(
              checked: currentLocale?.languageCode == 'ko',
              onChanged: (value) {
                if (value) {
                  appTheme.locale = const Locale('ko');
                }
              },
              content: const Text('한국어'),
            ),
            // Japanese
            RadioButton(
              checked: currentLocale?.languageCode == 'ja',
              onChanged: (value) {
                if (value) {
                  appTheme.locale = const Locale('ja');
                }
              },
              content: const Text('日本語'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorBlock(AppTheme appTheme, AccentColor color) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Button(
        onPressed: () {
          appTheme.color = color;
        },
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isPressed) {
              return color.light;
            } else if (states.isHovered) {
              return color.lighter;
            }
            return color;
          }),
        ),
        child: Container(
          height: 40,
          width: 40,
          alignment: AlignmentDirectional.center,
          child: appTheme.color == color
              ? Icon(
            FluentIcons.check_mark,
            color: color.basedOnLuminance(),
            size: 22.0,
          )
              : null,
        ),
      ),
    );
  }
}
