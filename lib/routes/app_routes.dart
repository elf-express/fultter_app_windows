import 'package:flutter/material.dart' hide Colors;
import 'package:fluent_ui/fluent_ui.dart';
import '../screens/home_screen.dart';

class AppRoutes {
  static const String home = '/';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomeScreen(
            //title: 'My Flutter App',
          ),
      // Add more routes here as needed
    };
  }

  // Helper method to push a named route
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }
}
