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
  Timer? _launchTimer;
  bool _showLaunchScreen = true;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _notificationSubscription =
        _appState.notificationEvents.listen(_showLiveNotification);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_appState.initialize());
    _launchTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showLaunchScreen = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _launchTimer?.cancel();
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
            home: _showLaunchScreen
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

class _LaunchScreen extends StatefulWidget {
  const _LaunchScreen();

  @override
  State<_LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<_LaunchScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _introController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

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
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _LaunchAmbientGlow(
              alignment: Alignment(-1.1, -1.05),
              color: TazaColors.accent,
              size: 260,
            ),
            const _LaunchAmbientGlow(
              alignment: Alignment(1.1, .95),
              color: TazaColors.accent2,
              size: 220,
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _introController,
                    curve: Curves.easeOut,
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .94, end: 1).animate(
                      CurvedAnimation(
                        parent: _introController,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(
                              context,
                              ar: 'تجربة تازا تبدأ الآن',
                              en: 'Your TAZA experience begins now',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: TazaColors.accent2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6,
                                ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 154,
                            height: 154,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                RotationTransition(
                                  turns: _orbitController,
                                  child: const _LaunchRing(
                                    inset: 0,
                                    color: Color(0x55FFC968),
                                  ),
                                ),
                                RotationTransition(
                                  turns: Tween<double>(begin: 0, end: -1)
                                      .animate(_orbitController),
                                  child: const _LaunchRing(
                                    inset: 10,
                                    color: Color(0x44FF8A2B),
                                  ),
                                ),
                                Container(
                                  width: 102,
                                  height: 102,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: TazaColors.accent
                                            .withValues(alpha: .28),
                                        blurRadius: 30,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(25),
                                    child: Image.asset(
                                      AppAssets.logo,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  top: 12,
                                  right: 24,
                                  child: _LaunchSpark(size: 7),
                                ),
                                const Positioned(
                                  bottom: 18,
                                  left: 18,
                                  child: _LaunchSpark(size: 5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'TAZA '),
                                TextSpan(
                                  text: '041',
                                  style:
                                      const TextStyle(color: TazaColors.accent),
                                ),
                              ],
                            ),
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  color: TazaColors.textLight,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.2,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tr(
                              context,
                              ar: 'نكهة تجمعنا',
                              en: 'Flavor brings us together',
                            ),
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: TazaColors.mutedDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaunchAmbientGlow extends StatelessWidget {
  const _LaunchAmbientGlow({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .18), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _LaunchRing extends StatelessWidget {
  const _LaunchRing({required this.inset, required this.color});

  final double inset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(inset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(58),
          border: Border(
            top: BorderSide(color: color, width: 1.4),
            right: BorderSide(color: color, width: 1.4),
            bottom: BorderSide(color: color.withValues(alpha: .18)),
            left: BorderSide(color: color.withValues(alpha: .18)),
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LaunchSpark extends StatelessWidget {
  const _LaunchSpark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TazaColors.accent2,
        boxShadow: const [
          BoxShadow(color: TazaColors.accent2, blurRadius: 12),
        ],
      ),
    );
  }
}
