import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';
import 'journal_screen.dart';
import 'more_screen.dart';
import 'timeline_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      DashboardScreen(),
      TimelineScreen(),
      JournalScreen(),
      ChatScreen(),
      MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.tr('nav_home')),
          NavigationDestination(icon: const Icon(Icons.timeline_outlined), selectedIcon: const Icon(Icons.timeline), label: context.tr('nav_timeline')),
          NavigationDestination(icon: const Icon(Icons.edit_note_outlined), selectedIcon: const Icon(Icons.edit_note), label: context.tr('nav_journal')),
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), selectedIcon: const Icon(Icons.chat_bubble), label: context.tr('nav_ask')),
          NavigationDestination(icon: const Icon(Icons.more_horiz), label: context.tr('nav_more')),
        ],
      ),
    );
  }
}
