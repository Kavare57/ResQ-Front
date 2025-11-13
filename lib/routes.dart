import 'package:flutter/material.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      default:
        return MaterialPageRoute(builder: (_) => const LoginPage());
    }
  }
}
