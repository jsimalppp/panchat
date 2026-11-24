import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/locale_store.dart';
import 'data/theme_store.dart';
import 'data/providers.dart';

class PanchatApp extends ConsumerWidget {
  const PanchatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Panchat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Arabic first: anything that is not English falls back to Arabic (RTL).
      localeResolutionCallback: (device, supported) {
        if (device != null && device.languageCode == 'en') return const Locale('en');
        return const Locale('ar');
      },
    );
  }
}

class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(c.tr('configMissing'), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps "last seen" fresh while the app is in the foreground.
class PresenceKeeper extends ConsumerStatefulWidget {
  const PresenceKeeper({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PresenceKeeper> createState() => _PresenceKeeperState();
}

class _PresenceKeeperState extends ConsumerState<PresenceKeeper>
    with WidgetsBindingObserver {
  Timer? _timer;

  void _touch() => ref.read(profileRepoProvider).touchPresence();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _touch();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _touch());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      _touch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
