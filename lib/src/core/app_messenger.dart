import 'package:flutter/material.dart';

/// Stable application-level keys used for messages and navigation that may
/// outlive the screen which started an asynchronous operation.
class AppMessenger {
  AppMessenger._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void show(String message, {SnackBarAction? action}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}
