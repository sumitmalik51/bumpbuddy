import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  store.load();
  runApp(BumpBuddyApp(store: store));
}

class BumpBuddyApp extends StatelessWidget {
  final AppStore store;
  const BumpBuddyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'BumpBuddy',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: Consumer<AppStore>(
          builder: (context, store, _) {
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
