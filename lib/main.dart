import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'activity_list_page.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  // Initialize sqflite for desktop using FFI
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await ThemeService.init();
  runApp(const MyApp());
  // Start background notification check
  NotificationService().start();
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // pastel / pink themed light look matching the mock
    final base = ThemeData.light();
    final primaryPink = const Color(0xFFF7E8EE);
    final accentPink = const Color(0xFFDEC0D6);
    final textPrimary = const Color(0xFF1F1B24);

    final lightTheme = base.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: textPrimary,
        selectionColor: primaryPink.withOpacity(0.4),
        selectionHandleColor: textPrimary,
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: primaryPink,
        secondary: accentPink,
        surface: Colors.white,
        background: primaryPink.withOpacity(0.6),
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7EEF2),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryPink,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textPrimary),
      ),
      dividerColor: Colors.grey.shade300,
      iconTheme: IconThemeData(color: textPrimary.withOpacity(0.8)),
      listTileTheme: ListTileThemeData(textColor: textPrimary, iconColor: textPrimary.withOpacity(0.8)),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        textStyle: TextStyle(color: textPrimary),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accentPink,
        labelStyle: TextStyle(color: textPrimary),
        secondaryLabelStyle: TextStyle(color: textPrimary),
        selectedColor: primaryPink,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 32, color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: base.textTheme.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPink,
          foregroundColor: textPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: textPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: textPrimary.withOpacity(0.8)),
        hintStyle: TextStyle(color: textPrimary.withOpacity(0.6)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentPink)),
        border: OutlineInputBorder(),
        fillColor: Colors.white,
        filled: true,
      ),
      snackBarTheme: SnackBarThemeData(contentTextStyle: TextStyle(color: textPrimary)),
      useMaterial3: false,
    );

    // Dark theme (based on previous dark look)
    final darkBase = ThemeData.dark();
    final primaryDark = const Color(0xFF1C1B21);
    final accentDark = const Color(0xFF6C4B8B);
    final textOnDark = Colors.white;
    final darkTheme = darkBase.copyWith(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentDark,
        selectionColor: accentDark.withOpacity(0.25),
        selectionHandleColor: accentDark,
      ),
      colorScheme: darkBase.colorScheme.copyWith(
        primary: primaryDark,
        secondary: accentDark,
        surface: const Color(0xFF141416),
        background: const Color(0xFF0F0F10),
        onPrimary: textOnDark,
        onSecondary: textOnDark,
        onSurface: textOnDark,
        onBackground: textOnDark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F10),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: textOnDark,
        iconTheme: IconThemeData(color: textOnDark),
        actionsIconTheme: IconThemeData(color: textOnDark),
      ),
      dividerColor: Colors.grey.shade800,
      iconTheme: IconThemeData(color: textOnDark.withOpacity(0.9)),
      listTileTheme: ListTileThemeData(textColor: textOnDark, iconColor: textOnDark.withOpacity(0.9)),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF161618),
        textStyle: TextStyle(color: textOnDark),
      ),
      chipTheme: darkBase.chipTheme.copyWith(
        backgroundColor: accentDark.withOpacity(0.2),
        labelStyle: TextStyle(color: textOnDark),
        secondaryLabelStyle: TextStyle(color: textOnDark),
        selectedColor: accentDark.withOpacity(0.3),
      ),
      textTheme: darkBase.textTheme.copyWith(
        headlineSmall: darkBase.textTheme.headlineSmall?.copyWith(fontSize: 32, color: textOnDark, fontWeight: FontWeight.w600),
        titleMedium: darkBase.textTheme.titleMedium?.copyWith(color: textOnDark, fontWeight: FontWeight.w600),
        bodyMedium: darkBase.textTheme.bodyMedium?.copyWith(color: textOnDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentDark,
          foregroundColor: textOnDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: textOnDark.withOpacity(0.85)),
        hintStyle: TextStyle(color: textOnDark.withOpacity(0.6)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade800)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentDark)),
        border: OutlineInputBorder(),
        fillColor: const Color(0xFF161618),
        filled: true,
      ),
      snackBarTheme: SnackBarThemeData(contentTextStyle: TextStyle(color: textOnDark)),
      useMaterial3: false,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Log Work',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: ActivityListPage(),
        );
      },
    );
  }
}
