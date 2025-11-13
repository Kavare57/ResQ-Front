import 'package:flutter/material.dart';

class ResQColors {
  // Escala (tu paleta)
  static const Color primary50  = Color(0xFFFFF5F2);
  static const Color primary100 = Color(0xFFFFE5E0);
  static const Color primary200 = Color(0xFFFFC7B8);
  static const Color primary300 = Color(0xFFFF9F85);
  static const Color primary400 = Color(0xFFFF6D4A);
  static const Color primary500 = Color(0xFFFF4D2D);
  static const Color primary600 = Color(0xFFE24324);
  static const Color primary700 = Color(0xFFB7311B);
  static const Color primary800 = Color(0xFF8F2415);
  static const Color primary900 = Color(0xFF741E12);

  // Semánticos rápidos
  static const Color primary     = primary500;
  static const Color primaryDark = primary700;
  static const Color primaryLight= primary100;

  // Superficie / texto (ajústalos si usas fondos claros/osc.)
  static const Color surface    = Colors.white;
  static const Color onSurface  = Color(0xFF1A1A1A);
  static const Color onPrimary  = Colors.white;

  // Swatch para ThemeData.primarySwatch
  static const MaterialColor primarySwatch = MaterialColor(
    0xFFFF4D2D,
    <int, Color>{
      50:  primary50,
      100: primary100,
      200: primary200,
      300: primary300,
      400: primary400,
      500: primary500,
      600: primary600,
      700: primary700,
      800: primary800,
      900: primary900,
    },
  );
}
