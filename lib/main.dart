import 'package:flutter/material.dart';
import 'routes.dart';
import 'core/constants/colors.dart';

void main() => runApp(const ResQApp());

class ResQApp extends StatelessWidget {
  const ResQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQ',
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      initialRoute: AppRoutes.login,
      theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: ResQColors.primary500,
      scaffoldBackgroundColor: ResQColors.primary50,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ResQColors.primary600),
      ),
    ),
    );
  }
}