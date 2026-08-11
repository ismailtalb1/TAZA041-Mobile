import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/app_state.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';
import 'package:taza041_flutter_customer_mobile/src/screens.dart';
import 'package:taza041_flutter_customer_mobile/src/widgets.dart';

void main() {
  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('guest home has no layout exception at ${width.toInt()}dp',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState();
      addTearDown(state.dispose);
      await tester.pumpWidget(
        AppStateScope(
          notifier: state,
          child: const MaterialApp(home: GuestHomeScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('TAZA 041'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'all customer screens mount without overflow at ${width.toInt()}dp',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState()
        ..isAuthenticated = true
        ..currentUser = AppUser(
          fullName: 'TAZA Customer',
          email: 'customer@example.com',
          phone: '+963900000000',
          loyaltyPoints: 120,
        );
      addTearDown(state.dispose);
      final screens = <Widget>[
        const LoginScreen(),
        const RegisterScreen(),
        const ForgotPasswordScreen(),
        const ResetPasswordScreen(),
        const RegisteredHomeScreen(),
        const MenuScreen(args: MenuRouteArgs(orderType: OrderType.ordinary)),
        const DeliveryScreen(),
        const ReservationScreen(),
        const PaymentScreen(),
        const NotificationsScreen(),
        const ProfileSettingsScreen(),
        const OrdersHistoryScreen(),
        const AiSuggestionScreen(),
        const AboutScreen(),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(
          AppStateScope(
            notifier: state,
            child: MaterialApp(home: screen),
          ),
        );
        await tester.pump();
        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: [
            '${screen.runtimeType} failed at ${width.toInt()}dp',
            if (exception is FlutterError) exception.toStringDeep(),
            if (exception is FlutterError) _overflowReport(tester),
          ].join('\n'),
        );
      }
    });
  }
}

String _overflowReport(WidgetTester tester) {
  final reports = <String>[];
  for (final renderObject in tester.allRenderObjects.whereType<RenderFlex>()) {
    var exceedsBounds = false;
    renderObject.visitChildren((child) {
      if (child is! RenderBox) return;
      final parentData = child.parentData;
      if (parentData is! FlexParentData) return;
      final rect = parentData.offset & child.size;
      if (rect.left < -.5 ||
          rect.top < -.5 ||
          rect.right > renderObject.size.width + .5 ||
          rect.bottom > renderObject.size.height + .5) {
        exceedsBounds = true;
      }
    });
    if (exceedsBounds) reports.add(renderObject.toStringDeep());
  }
  return reports.join('\n');
}
