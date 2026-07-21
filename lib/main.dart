import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'notification_service.dart';
import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await NotificationService.instance.init();
  await store.load();
  // Re-sync schedules on every launch so reminders survive reboots.
  if (store.profile?.delivered == true) {
    await NotificationService.instance.cancelAll();
  } else {
    await NotificationService.instance.syncMedicines(store.medicines);
    await NotificationService.instance.syncAppointments(store.appointments);
    await NotificationService.instance
        .syncKickReminder(store.profile, store.kickReminderEnabled);
  }
  runApp(BumpBuddyApp(store: store));
}

class BumpBuddyApp extends StatelessWidget {
  final AppStore store;
  const BumpBuddyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: Consumer<AppStore>(
        builder: (context, store, _) => MaterialApp(
          title: 'My Pregnancy',
          debugShowCheckedModeBanner: false,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          locale: store.loaded ? Locale(store.languageCode) : null,
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              if (!store.loaded) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return store.profile == null
                  ? const SetupScreen()
                  : const HomeShell();
            },
          ),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB84D7B), // warm rose
      brightness: b,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
