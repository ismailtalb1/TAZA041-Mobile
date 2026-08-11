import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taza041_flutter_customer_mobile/src/app_state.dart';
import 'package:taza041_flutter_customer_mobile/src/models.dart';
import 'package:taza041_flutter_customer_mobile/src/widgets.dart';

void main() {
  testWidgets('menu stays at the start edge before the back button',
      (tester) async {
    final state = AppState()..isAuthenticated = true;
    addTearDown(state.dispose);

    Future<void> pumpShell(AppLanguage language) async {
      state.language = language;
      await tester.pumpWidget(
        AppStateScope(
          notifier: state,
          child: const MaterialApp(
            home: TazaShell(
              titleAr: 'اختبار',
              titleEn: 'Test',
              registered: true,
              showBack: true,
              body: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    const menuKey = ValueKey('taza-menu-button');
    const backKey = ValueKey('taza-back-button');

    await pumpShell(AppLanguage.ar);
    expect(tester.getCenter(find.byKey(menuKey)).dx,
        greaterThan(tester.getCenter(find.byKey(backKey)).dx));

    state.toggleLanguage();
    await tester.pump();
    expect(tester.getCenter(find.byKey(menuKey)).dx,
        lessThan(tester.getCenter(find.byKey(backKey)).dx));
  });

  testWidgets('guest actions and appearance controls flank a centered brand',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppStateScope(
        notifier: state,
        child: const MaterialApp(
          home: TazaShell(
            titleAr: 'الرئيسية',
            titleEn: 'Home',
            startActions: [
              IconButton(
                key: ValueKey('login-action'),
                onPressed: null,
                icon: Icon(Icons.login_rounded),
              ),
              IconButton(
                key: ValueKey('register-action'),
                onPressed: null,
                icon: Icon(Icons.person_add_alt_1_rounded),
              ),
            ],
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();

    final brandCenter = tester.getCenter(
      find.byKey(const ValueKey('taza-logo-title')),
    );
    final loginCenter = tester.getCenter(
      find.byKey(const ValueKey('login-action')),
    );
    final themeCenter = tester.getCenter(
      find.byKey(const ValueKey('taza-theme-button')),
    );
    expect(brandCenter.dx, closeTo(195, 1));
    expect(loginCenter.dx, greaterThan(brandCenter.dx));
    expect(themeCenter.dx, lessThan(brandCenter.dx));
  });
}
