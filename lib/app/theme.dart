import 'package:flutter/material.dart';

class PrismColors {
  // Core palette keeps the existing semantic names so gameplay code stays
  // untouched, while the visual language moves to a bright casual-game style.
  static const midnight = Color(0xff654d64);
  static const navy = Color(0xff765b70);
  static const panel = Color(0xff8a6879);
  static const panelSoft = Color(0xff9c7885);
  static const ink = Color(0xfffffbf5);
  static const muted = Color(0xffead9cf);
  static const yellow = Color(0xffffd43e);
  static const orange = Color(0xffff8a35);
  static const green = Color(0xff9bd528);
  static const cyan = Color(0xff54c8ed);
  static const pink = Color(0xffef4b98);
  static const violet = Color(0xff9d76d8);

  static const blockColors = [
    Color(0xff54c8ed),
    Color(0xffef5752),
    Color(0xffffc93f),
    Color(0xffa678d8),
    Color(0xff8ed334),
    Color(0xffff8a35),
    Color(0xffe85aa8),
  ];

  static const rainbow = [
    Color(0xffef5752),
    Color(0xffff8a35),
    Color(0xffffd43e),
    Color(0xff8ed334),
    Color(0xff54c8ed),
    Color(0xff9d76d8),
    Color(0xffef4b98),
  ];
}

ThemeData prismTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: PrismColors.midnight,
    colorScheme: const ColorScheme.dark(
      primary: PrismColors.green,
      secondary: PrismColors.pink,
      surface: PrismColors.navy,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: PrismColors.ink,
    ),
    fontFamily: 'Arial',
    useMaterial3: true,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xff8d6975),
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: .5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PrismColors.green,
        foregroundColor: Colors.white,
        elevation: 7,
        shadowColor: Colors.black45,
        minimumSize: const Size(0, 54),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: .42), width: 2),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PrismColors.green,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PrismColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xfffff5e8),
      titleTextStyle: const TextStyle(
        color: Color(0xff74452f),
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      contentTextStyle: const TextStyle(
        color: Color(0xff9a705a),
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xff78658f), width: 5),
      ),
    ),
  );
}

BoxDecoration prismPanel({double radius = 18}) => BoxDecoration(
  color: PrismColors.panel.withValues(alpha: .94),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withValues(alpha: .18), width: 2),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: .28),
      blurRadius: 10,
      offset: const Offset(5, 8),
    ),
  ],
);
