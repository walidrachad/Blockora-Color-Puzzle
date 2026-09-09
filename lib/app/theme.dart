import 'package:flutter/material.dart';

class PrismColors {
  static const midnight = Color(0xff08123a);
  static const navy = Color(0xff101a4a);
  static const panel = Color(0xff162257);
  static const panelSoft = Color(0xff202c6c);
  static const ink = Color(0xfff7f8ff);
  static const muted = Color(0xff9ca8da);
  static const yellow = Color(0xffffc95d);
  static const orange = Color(0xffff895e);
  static const green = Color(0xff54e59b);
  static const cyan = Color(0xff63dcff);
  static const pink = Color(0xffff71c8);
  static const violet = Color(0xffa77cff);

  static const blockColors = [
    Color(0xff62dfff),
    Color(0xffff75c8),
    Color(0xffffc85b),
    Color(0xff8f7cff),
    Color(0xff61e4a1),
    Color(0xffff8d69),
    Color(0xffb98cff),
  ];

  static const rainbow = [
    Color(0xffff6e8a),
    Color(0xffffb45c),
    Color(0xffffe56b),
    Color(0xff6be8a7),
    Color(0xff67dfff),
    Color(0xffa684ff),
    Color(0xffff79d2),
  ];
}

ThemeData prismTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: PrismColors.midnight,
  colorScheme: const ColorScheme.dark(
    primary: PrismColors.cyan,
    secondary: PrismColors.pink,
    surface: PrismColors.navy,
  ),
  fontFamily: 'Arial',
  useMaterial3: true,
);

BoxDecoration prismPanel({double radius = 18}) => BoxDecoration(
  color: PrismColors.panel.withValues(alpha: .82),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withValues(alpha: .08)),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: .26),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ],
);
