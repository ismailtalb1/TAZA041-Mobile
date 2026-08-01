import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'src/app_state.dart';
import 'src/router.dart';
import 'src/screens.dart';
import 'src/theme.dart';
import 'src/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: TazaColors.darkBg,
  ));
  runApp(const Taza041App());
}

class Taza041App extends StatefulWidget {
  const Taza041App({super.key});

  @override
  State<Taza041App> createState() => _Taza041AppState();
}

class _Taza041AppState extends State<Taza041App> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    unawaited(_appState.initialize());
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _appState,
      child: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          return MaterialApp(
            title: 'TAZA 041',
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
                  'assets/images/taza041-logo.jpg',
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'TAZA 041',
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
