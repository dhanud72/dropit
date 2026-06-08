import 'package:flutter/material.dart';

class Neu {
  static const bg = Color(0xFFE8EBF0);
  static const accent = Color(0xFFF5A623);
  static const textPrimary = Color(0xFF2C3E50);
  static const textSecondary = Color(0xFF8A9BB0);
  static const _light = Color(0xFFFFFFFF);
  static const _dark = Color(0xFFA3B1C6);

  static List<BoxShadow> raised({double depth = 6}) => [
        BoxShadow(
          color: _light,
          offset: Offset(-depth * 0.7, -depth * 0.7),
          blurRadius: depth * 1.5,
        ),
        BoxShadow(
          color: _dark.withValues(alpha: 0.7),
          offset: Offset(depth * 0.7, depth * 0.7),
          blurRadius: depth * 1.5,
        ),
      ];

  static List<BoxShadow> pressed() => [
        BoxShadow(
          color: _dark.withValues(alpha: 0.5),
          offset: const Offset(-3, -3),
          blurRadius: 6,
        ),
        const BoxShadow(
          color: _light,
          offset: Offset(3, 3),
          blurRadius: 6,
        ),
      ];

  static BoxDecoration card({double radius = 16, double depth = 6}) =>
      BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: raised(depth: depth),
      );

  static BoxDecoration inset({double radius = 12}) => BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFA3B1C6),
            offset: Offset(3, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-3, -3),
            blurRadius: 6,
          ),
        ],
      );
}
