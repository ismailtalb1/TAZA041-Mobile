import 'package:flutter/material.dart';

import 'models.dart';
import 'screens.dart';

class AppRoutes {
  static const guestHome = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const homeUser = '/home-user';
  static const menu = '/menu';
  static const delivery = '/delivery';
  static const reservation = '/reservation';
  static const payment = '/payment';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const orders = '/orders';
  static const aiSuggestion = '/ai-suggestion';
  static const about = '/about';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case AppRoutes.guestHome:
        page = const GuestHomeScreen();
      case AppRoutes.login:
        page = const LoginScreen();
      case AppRoutes.register:
        page = const RegisterScreen();
      case AppRoutes.forgotPassword:
        page = const ForgotPasswordScreen();
      case AppRoutes.resetPassword:
        page = const ResetPasswordScreen();
      case AppRoutes.homeUser:
        page = const RegisteredHomeScreen();
      case AppRoutes.menu:
        final args = settings.arguments is MenuRouteArgs
            ? settings.arguments as MenuRouteArgs
            : const MenuRouteArgs(orderType: OrderType.ordinary);
        page = MenuScreen(args: args);
      case AppRoutes.delivery:
        page = const DeliveryScreen();
      case AppRoutes.reservation:
        page = const ReservationScreen();
      case AppRoutes.payment:
        page = const PaymentScreen();
      case AppRoutes.notifications:
        page = const NotificationsScreen();
      case AppRoutes.profile:
        page = const ProfileSettingsScreen();
      case AppRoutes.orders:
        page = const OrdersHistoryScreen();
      case AppRoutes.aiSuggestion:
        final args = settings.arguments is MealConversationRouteArgs
            ? settings.arguments as MealConversationRouteArgs
            : const MealConversationRouteArgs();
        page = MealConversationsScreen(args: args);
      case AppRoutes.about:
        page = const AboutScreen();
      default:
        page = const Scaffold(body: Center(child: Text('Route not found')));
    }
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final offset = Tween<Offset>(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }
}
