import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'src/app_state.dart';
import 'src/api_client.dart';
import 'src/core/app_constants.dart';
import 'src/core/app_messenger.dart';
import 'src/models.dart';
import 'src/router.dart';
import 'src/screens.dart';
import 'src/theme.dart';
import 'src/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: TazaColors.darkBg,
  ));
  if (kReleaseMode && !ApiConfig.hasSecureProductionEndpoint) {
    runApp(const _ReleaseConfigurationErrorApp());
    return;
  }
  runApp(const Taza041App());
}

class _ReleaseConfigurationErrorApp extends StatelessWidget {
  const _ReleaseConfigurationErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: TazaColors.darkBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security_rounded,
                      color: TazaColors.accent, size: 54),
                  SizedBox(height: 18),
                  Text(
                    'تعذر تشغيل النسخة الإنتاجية بأمان.\nProduction endpoint is not configured securely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TazaColors.textLight,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Taza041App extends StatefulWidget {
  const Taza041App({super.key});

  @override
  State<Taza041App> createState() => _Taza041AppState();
}

class _Taza041AppState extends State<Taza041App> with WidgetsBindingObserver {
  late final AppState _appState;
  late final StreamSubscription<NotificationItem> _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _notificationSubscription =
        _appState.notificationEvents.listen(_showLiveNotification);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_appState.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription.cancel();
    _appState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState.setForeground(state == AppLifecycleState.resumed);
  }

  void _showLiveNotification(NotificationItem item) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notificationContext = AppMessenger.navigatorKey.currentContext;
      final message = notificationContext == null
          ? (_appState.language == AppLanguage.ar
              ? '${item.titleAr}\n${item.messageAr}'
              : '${item.titleEn}\n${item.messageEn}')
          : '${notificationTitle(notificationContext, item)}\n'
              '${notificationMessage(notificationContext, item)}';
      AppMessenger.show(
        message,
        action: SnackBarAction(
          label: _appState.language == AppLanguage.ar ? 'عرض' : 'View',
          onPressed: () => AppMessenger.navigatorKey.currentState
              ?.pushNamed(AppRoutes.notifications),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _appState,
      child: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          return MaterialApp(
            title: AppConstants.appName,
            navigatorKey: AppMessenger.navigatorKey,
            scaffoldMessengerKey: AppMessenger.messengerKey,
            debugShowCheckedModeBanner: false,
            locale: Locale(_appState.language.code),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: _appState.isDarkMode
                ? TazaThemes.dark(_appState.language)
                : TazaThemes.light(_appState.language),
            onGenerateRoute: AppRouter.generateRoute,
            home: _appState.isInitializing
                ? const _LaunchScreen()
                : _appState.isAuthenticated
                    ? const RegisteredHomeScreen()
                    : const GuestHomeScreen(),
          );
        },
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [TazaColors.darkBg, TazaColors.darkBg2],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  AppAssets.logo,
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: TazaColors.textLight,
                    ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
