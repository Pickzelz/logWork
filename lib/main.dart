import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'activity_list_page.dart';
import 'services/notification_service.dart';

void main() {
  // Initialize sqflite for desktop using FFI
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
  // Start background notification check
  NotificationService().start();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    return MaterialApp(
      title: 'Log Work',
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: Color(0xFF0A0A0A),
          secondary: Color(0xFF3A3D45),
          surface: Color(0xFF0A0A0A),
          background: Color(0xFF000000),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        listTileTheme: const ListTileThemeData(textColor: Colors.white, iconColor: Colors.white70),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF1E1E1E),
          textStyle: TextStyle(color: Colors.white),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: const Color(0xFF2D2D2D),
          labelStyle: const TextStyle(color: Colors.white),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          selectedColor: const Color(0xFF3A3D45),
        ),
        textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2D2D2D),
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white54),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
          border: OutlineInputBorder(),
          fillColor: Color(0xFF0E0E0E),
          filled: true,
        ),
        snackBarTheme: const SnackBarThemeData(contentTextStyle: TextStyle(color: Colors.white)),
        useMaterial3: false,
      ),
      home: ActivityListPage(),
    );
  }
}
