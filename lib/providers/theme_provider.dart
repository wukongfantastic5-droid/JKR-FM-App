import 'package:flutter/material.dart';

class ThemeProvider extends InheritedNotifier<ValueNotifier<bool>> {
  const ThemeProvider({
    super.key,
    required ValueNotifier<bool> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool isDark(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ThemeProvider>()
            ?.notifier
            ?.value ??
        false;
  }

  static ValueNotifier<bool> themeNotifier(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeProvider>()!
        .notifier!;
  }
}
